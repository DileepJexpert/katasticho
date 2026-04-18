import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/k_colors.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';
import '../../features/comments/data/comment_repository.dart';

/// Full activity/comments tab — drop this as a tab child in any detail screen.
///
/// Usage:
/// ```dart
/// KActivityTimeline(entityType: 'INVOICE', entityId: invoiceId)
/// ```
///
/// entityType is the API entity type string (e.g. 'INVOICE', 'BILL',
/// 'CONTACT', 'ESTIMATE').
class KActivityTimeline extends ConsumerStatefulWidget {
  final String entityType;
  final String entityId;

  const KActivityTimeline({
    super.key,
    required this.entityType,
    required this.entityId,
  });

  @override
  ConsumerState<KActivityTimeline> createState() => _KActivityTimelineState();
}

class _KActivityTimelineState extends ConsumerState<KActivityTimeline> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _submitting = false;

  ({String entityType, String entityId}) get _key =>
      (entityType: widget.entityType, entityId: widget.entityId);

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final repo = ref.read(commentRepositoryProvider);
      await repo.addComment(widget.entityType, widget.entityId, text);
      _controller.clear();
      ref.invalidate(commentsProvider(_key));
      await Future.delayed(const Duration(milliseconds: 300));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add comment')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(_key));
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: commentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: cs.error, size: 40),
                  KSpacing.vGapSm,
                  Text('Failed to load activity',
                      style: KTypography.bodyMedium),
                  KSpacing.vGapSm,
                  TextButton(
                    onPressed: () => ref.invalidate(commentsProvider(_key)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (comments) {
              if (comments.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 48,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                      KSpacing.vGapMd,
                      Text('No activity yet',
                          style: KTypography.h4.copyWith(
                              color: cs.onSurfaceVariant)),
                      KSpacing.vGapXs,
                      Text('Add a note below to start the conversation.',
                          style: KTypography.bodySmall.copyWith(
                              color: cs.onSurfaceVariant)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: comments.length,
                itemBuilder: (context, i) =>
                    _CommentTile(comment: comments[i], index: i),
              );
            },
          ),
        ),

        // ── Add comment input ──────────────────────────────────────
        _CommentInputBar(
          controller: _controller,
          submitting: _submitting,
          onSubmit: _submit,
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final int index;

  const _CommentTile({required this.comment, required this.index});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = comment['text'] as String? ?? '';
    final author = comment['createdByName'] as String?
        ?? comment['authorName'] as String?
        ?? 'User';
    final createdAt = comment['createdAt'] as String?
        ?? comment['timestamp'] as String?;
    final initials = author.isNotEmpty
        ? author.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join()
        : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline connector + avatar
          Column(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: cs.primary.withValues(alpha: 0.15),
                child: Text(
                  initials.toUpperCase(),
                  style: KTypography.labelSmall.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          KSpacing.hGapSm,
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(KSpacing.radiusMd),
                border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          author,
                          style: KTypography.labelSmall.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (createdAt != null)
                        Text(
                          _formatTime(createdAt),
                          style: KTypography.labelSmall.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                  KSpacing.vGapXs,
                  Text(text,
                      style: KTypography.bodyMedium.copyWith(
                          color: cs.onSurface)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

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
              textInputAction: TextInputAction.newline,
              style: KTypography.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Add a note or comment…',
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
                      strokeWidth: 2, color: cs.primary),
                )
              : IconButton(
                  onPressed: onSubmit,
                  icon: const Icon(Icons.send_rounded),
                  color: cs.primary,
                  tooltip: 'Send',
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
