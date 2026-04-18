import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/k_colors.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';
import '../../features/comments/data/comment_repository.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

/// A single entry on the unified activity timeline.
///
/// Use [KTimelineEvent.system] for backend/state-derived events (created,
/// sent, payment recorded…). Use [KTimelineEvent.comment] to wrap a raw
/// comment map from the API — [KActivityTimeline] does this automatically.
class KTimelineEvent {
  final DateTime timestamp;
  final String message;
  final String? subtext;
  final String? authorName;
  final bool isSystem;
  final IconData icon;
  final Color color;

  const KTimelineEvent({
    required this.timestamp,
    required this.message,
    this.subtext,
    this.authorName,
    this.isSystem = true,
    required this.icon,
    required this.color,
  });

  /// Convenience constructor for a system/audit event.
  factory KTimelineEvent.system({
    required DateTime timestamp,
    required String message,
    String? subtext,
    String? by,
    IconData icon = Icons.info_outline_rounded,
    Color color = KColors.info,
  }) =>
      KTimelineEvent(
        timestamp: timestamp,
        message: message,
        subtext: subtext,
        authorName: by,
        isSystem: true,
        icon: icon,
        color: color,
      );

  /// Wraps a raw comment map from `/api/v1/comments/…`.
  factory KTimelineEvent.fromComment(Map<String, dynamic> c) {
    final author = c['createdByName'] as String?
        ?? c['authorName'] as String?
        ?? 'User';
    final raw = c['createdAt'] as String? ?? c['timestamp'] as String?;
    final ts = raw != null ? DateTime.tryParse(raw) ?? DateTime.now() : DateTime.now();
    return KTimelineEvent(
      timestamp: ts,
      message: c['text'] as String? ?? '',
      authorName: author,
      isSystem: false,
      icon: Icons.chat_bubble_outline_rounded,
      color: KColors.primary,
    );
  }
}

// ── Widget ────────────────────────────────────────────────────────────────────

/// Unified activity & audit-trail tab.
///
/// Pass [systemEvents] (synthesized from entity data by the caller) alongside
/// [entityType] / [entityId] for comments. The widget merges both streams,
/// sorts newest-first, and renders a colour-coded timeline.
///
/// System events render as a tinted icon pill (no avatar).
/// User comments render as an avatar bubble with a compose-in-place reply bar.
class KActivityTimeline extends ConsumerStatefulWidget {
  final String entityType;
  final String entityId;

  /// Pre-computed system/audit events — e.g. "Invoice created", "Payment
  /// recorded". The widget merges these with fetched comments and sorts
  /// the whole list by timestamp (newest first).
  final List<KTimelineEvent> systemEvents;

  const KActivityTimeline({
    super.key,
    required this.entityType,
    required this.entityId,
    this.systemEvents = const [],
  });

  @override
  ConsumerState<KActivityTimeline> createState() => _KActivityTimelineState();
}

class _KActivityTimelineState extends ConsumerState<KActivityTimeline> {
  final _controller = TextEditingController();
  bool _submitting = false;

  ({String entityType, String entityId}) get _key =>
      (entityType: widget.entityType, entityId: widget.entityId);

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(commentRepositoryProvider)
          .addComment(widget.entityType, widget.entityId, text);
      _controller.clear();
      ref.invalidate(commentsProvider(_key));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add note')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(_key));

    return Column(
      children: [
        Expanded(
          child: commentsAsync.when(
            loading: () => _buildList(widget.systemEvents, loading: true),
            error: (_, __) => _buildList(widget.systemEvents, error: true),
            data: (comments) {
              final commentEvents =
                  comments.map(KTimelineEvent.fromComment).toList();
              final all = [...widget.systemEvents, ...commentEvents]
                ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
              return _buildList(all);
            },
          ),
        ),
        _CommentInputBar(
          controller: _controller,
          submitting: _submitting,
          onSubmit: _submit,
        ),
      ],
    );
  }

  Widget _buildList(List<KTimelineEvent> events,
      {bool loading = false, bool error = false}) {
    final cs = Theme.of(context).colorScheme;

    if (events.isEmpty && !loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded,
                size: 48,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
            KSpacing.vGapMd,
            Text('No activity yet',
                style:
                    KTypography.h4.copyWith(color: cs.onSurfaceVariant)),
            KSpacing.vGapXs,
            Text('Add a note below to start tracking this record.',
                style: KTypography.bodySmall
                    .copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: events.length + (loading ? 1 : 0) + (error ? 1 : 0),
      itemBuilder: (context, i) {
        if (loading && i == events.length) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (error && i == events.length) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 16, color: cs.error),
                KSpacing.hGapSm,
                Text('Could not load comments',
                    style: KTypography.bodySmall
                        .copyWith(color: cs.onSurfaceVariant)),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(commentsProvider(_key)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        final event = events[i];
        final isLast = i == events.length - 1;
        return _TimelineTile(event: event, isLast: isLast);
      },
    );
  }
}

// ── Timeline tile ─────────────────────────────────────────────────────────────

class _TimelineTile extends StatelessWidget {
  final KTimelineEvent event;
  final bool isLast;

  const _TimelineTile({required this.event, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Spine ──────────────────────────────────────────
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: event.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(event.icon, size: 16, color: event.color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          KSpacing.hGapSm,

          // ── Content ────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: event.isSystem
                  ? _SystemEventCard(event: event)
                  : _CommentCard(event: event),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemEventCard extends StatelessWidget {
  final KTimelineEvent event;
  const _SystemEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(event.message,
                  style: KTypography.bodyMedium.copyWith(
                      color: cs.onSurface, fontWeight: FontWeight.w500)),
            ),
            Text(
              _relTime(event.timestamp),
              style: KTypography.labelSmall
                  .copyWith(color: cs.onSurfaceVariant, fontSize: 10),
            ),
          ],
        ),
        if (event.subtext != null) ...[
          const SizedBox(height: 2),
          Text(event.subtext!,
              style: KTypography.bodySmall
                  .copyWith(color: cs.onSurfaceVariant)),
        ],
        if (event.authorName != null) ...[
          const SizedBox(height: 2),
          Text('by ${event.authorName}',
              style: KTypography.labelSmall
                  .copyWith(color: cs.onSurfaceVariant, fontSize: 10)),
        ],
      ],
    );
  }
}

class _CommentCard extends StatelessWidget {
  final KTimelineEvent event;
  const _CommentCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = (event.authorName ?? 'U')
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(KSpacing.radiusMd),
        border:
            Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: KColors.primary.withValues(alpha: 0.15),
                child: Text(initials,
                    style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: KColors.primary)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(event.authorName ?? 'User',
                    style: KTypography.labelSmall.copyWith(
                        color: KColors.primary,
                        fontWeight: FontWeight.w700)),
              ),
              Text(_relTime(event.timestamp),
                  style: KTypography.labelSmall
                      .copyWith(color: cs.onSurfaceVariant, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 6),
          Text(event.message,
              style: KTypography.bodyMedium.copyWith(color: cs.onSurface)),
        ],
      ),
    );
  }
}

// ── Compose bar ───────────────────────────────────────────────────────────────

class _CommentInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

  const _CommentInputBar({
    required this.controller,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, 8 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
            top: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              style: KTypography.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Add a note…',
                hintStyle: KTypography.bodyMedium.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(KSpacing.radiusMd),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(KSpacing.radiusMd),
                  borderSide: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(KSpacing.radiusMd),
                  borderSide: BorderSide(color: cs.primary),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
          ),
          KSpacing.hGapSm,
          submitting
              ? SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: cs.primary))
              : IconButton(
                  onPressed: onSubmit,
                  icon: const Icon(Icons.send_rounded),
                  color: cs.primary,
                  tooltip: 'Add note',
                  style: IconButton.styleFrom(
                    backgroundColor: cs.primary.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(KSpacing.radiusMd),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _relTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt.toLocal());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final d = dt.toLocal();
  return '${d.day}/${d.month}/${d.year}';
}
