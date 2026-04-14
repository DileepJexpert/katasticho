import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/estimate_repository.dart';

/// Pulls comments for a given estimate.
final _commentsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, estimateId) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiConfig.comments('ESTIMATE', estimateId));
  final data = (resp.data as Map<String, dynamic>)['data'];
  if (data is List) return data.cast<Map<String, dynamic>>();
  if (data is Map && data['content'] is List) {
    return (data['content'] as List).cast<Map<String, dynamic>>();
  }
  return const <Map<String, dynamic>>[];
});

class EstimateDetailScreen extends ConsumerWidget {
  final String estimateId;

  const EstimateDetailScreen({super.key, required this.estimateId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEstimate = ref.watch(estimateDetailProvider(estimateId));

    return asyncEstimate.when(
      loading: () => const Scaffold(body: KLoading()),
      error: (_, __) => Scaffold(
        appBar: AppBar(title: const Text('Estimate')),
        body: KErrorView(
          message: 'Failed to load estimate',
          onRetry: () => ref.invalidate(estimateDetailProvider(estimateId)),
        ),
      ),
      data: (data) {
        final raw = data['data'] ?? data;
        final estimate = raw as Map<String, dynamic>;
        final number = estimate['estimateNumber'] as String? ?? 'Estimate';
        final status = estimate['status'] as String? ?? 'DRAFT';

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(number),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Details'),
                  Tab(text: 'Comments'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _DetailsTab(
                  estimate: estimate,
                  estimateId: estimateId,
                ),
                _CommentsTab(estimateId: estimateId),
              ],
            ),
            bottomNavigationBar: _ActionBar(
              estimateId: estimateId,
              status: status,
            ),
          ),
        );
      },
    );
  }
}

class _DetailsTab extends StatelessWidget {
  final Map<String, dynamic> estimate;
  final String estimateId;

  const _DetailsTab({required this.estimate, required this.estimateId});

  @override
  Widget build(BuildContext context) {
    final status = estimate['status'] as String? ?? 'DRAFT';
    final subtotal = (estimate['subtotal'] as num?)?.toDouble() ?? 0;
    final discount = (estimate['discountAmount'] as num?)?.toDouble() ?? 0;
    final tax = (estimate['taxAmount'] as num?)?.toDouble() ?? 0;
    final total = (estimate['total'] as num?)?.toDouble() ?? 0;
    final contactName = estimate['contactName'] as String?;
    final subject = estimate['subject'] as String?;
    final reference = estimate['referenceNumber'] as String?;
    final notes = estimate['notes'] as String?;
    final terms = estimate['terms'] as String?;
    final estimateDate = estimate['estimateDate'] as String? ?? '';
    final expiryDate = estimate['expiryDate'] as String?;
    final sentAt = estimate['sentAt'] as String?;
    final acceptedAt = estimate['acceptedAt'] as String?;
    final declinedAt = estimate['declinedAt'] as String?;
    final convertedAt = estimate['convertedAt'] as String?;
    final convertedInvoiceId = estimate['convertedToInvoiceId']?.toString();
    final lines = (estimate['lines'] as List?) ?? const [];

    final statusColor = _statusColor(status);

    return SingleChildScrollView(
      padding: KSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero
          Center(
            child: Column(
              children: [
                Text('₹${total.toStringAsFixed(2)}',
                    style: KTypography.displayLarge),
                KSpacing.vGapXs,
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(status,
                      style: KTypography.labelMedium
                          .copyWith(color: statusColor)),
                ),
                KSpacing.vGapSm,
                Text(_formatDate(estimateDate),
                    style: KTypography.bodyMedium),
              ],
            ),
          ),
          KSpacing.vGapLg,

          _SectionHeader('Customer'),
          _Row('Customer', contactName ?? '—'),
          if (subject != null && subject.isNotEmpty)
            _Row('Subject', subject),
          if (reference != null && reference.isNotEmpty)
            _Row('Reference #', reference),
          if (expiryDate != null) _Row('Expires on', _formatDate(expiryDate)),
          KSpacing.vGapMd,

          _SectionHeader('Line items'),
          for (final l in lines)
            _LineTile(line: l as Map<String, dynamic>),
          KSpacing.vGapMd,

          _SectionHeader('Breakdown'),
          _Row('Subtotal', '₹${subtotal.toStringAsFixed(2)}'),
          if (discount > 0)
            _Row('Discount', '− ₹${discount.toStringAsFixed(2)}'),
          _Row('Tax', '₹${tax.toStringAsFixed(2)}'),
          const Divider(),
          _Row('Total', '₹${total.toStringAsFixed(2)}', bold: true),
          KSpacing.vGapMd,

          if ((notes != null && notes.isNotEmpty) ||
              (terms != null && terms.isNotEmpty)) ...[
            _SectionHeader('Notes & terms'),
            if (notes != null && notes.isNotEmpty) _Row('Notes', notes),
            if (terms != null && terms.isNotEmpty) _Row('Terms', terms),
            KSpacing.vGapMd,
          ],

          if (sentAt != null ||
              acceptedAt != null ||
              declinedAt != null ||
              convertedAt != null) ...[
            _SectionHeader('Lifecycle'),
            if (sentAt != null) _Row('Sent on', _formatDateTime(sentAt)),
            if (acceptedAt != null)
              _Row('Accepted on', _formatDateTime(acceptedAt)),
            if (declinedAt != null)
              _Row('Declined on', _formatDateTime(declinedAt)),
            if (convertedAt != null)
              _Row('Converted on', _formatDateTime(convertedAt)),
            KSpacing.vGapMd,
          ],

          if (convertedInvoiceId != null) ...[
            _SectionHeader('Linked invoice'),
            KCard(
              onTap: () =>
                  context.push('/invoices/$convertedInvoiceId'),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: KColors.primary),
                  KSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Invoice', style: KTypography.labelLarge),
                        KSpacing.vGapXs,
                        Text(convertedInvoiceId,
                            style: KTypography.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: KColors.textHint),
                ],
              ),
            ),
            KSpacing.vGapXl,
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'DRAFT' => KColors.textHint,
      'SENT' => KColors.info,
      'ACCEPTED' => KColors.success,
      'DECLINED' => KColors.error,
      'INVOICED' => KColors.primary,
      'EXPIRED' => KColors.warning,
      _ => KColors.textHint,
    };
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  String _formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _LineTile extends StatelessWidget {
  final Map<String, dynamic> line;

  const _LineTile({required this.line});

  @override
  Widget build(BuildContext context) {
    final description = line['description'] as String? ?? '';
    final quantity = (line['quantity'] as num?)?.toDouble() ?? 0;
    final rate = (line['rate'] as num?)?.toDouble() ?? 0;
    final amount = (line['amount'] as num?)?.toDouble() ?? 0;
    final taxRate = (line['taxRate'] as num?)?.toDouble() ?? 0;
    final discountPct = (line['discountPct'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(description, style: KTypography.labelLarge),
                ),
                Text('₹${amount.toStringAsFixed(2)}',
                    style: KTypography.labelLarge),
              ],
            ),
            KSpacing.vGapXs,
            Text(
              '${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 2)}'
              ' × ₹${rate.toStringAsFixed(2)}'
              '${discountPct > 0 ? ' • ${discountPct.toInt()}% off' : ''}'
              ' • GST ${taxRate.toInt()}%',
              style: KTypography.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends ConsumerWidget {
  final String estimateId;
  final String status;

  const _ActionBar({required this.estimateId, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nothing actionable once invoiced.
    if (status == 'INVOICED') return const SizedBox.shrink();

    final actions = <Widget>[];

    if (status == 'DRAFT' || status == 'SENT') {
      actions.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _runAction(
              context,
              ref,
              label: status == 'SENT' ? 'Re-sent' : 'Sent',
              action: (repo) => repo.sendEstimate(estimateId),
            ),
            icon: const Icon(Icons.send, size: 18),
            label: Text(status == 'SENT' ? 'Re-send' : 'Send'),
          ),
        ),
      );
    }

    if (status == 'DRAFT' || status == 'SENT') {
      if (actions.isNotEmpty) actions.add(KSpacing.hGapSm);
      actions.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _runAction(
              context,
              ref,
              label: 'Accepted',
              action: (repo) => repo.acceptEstimate(estimateId),
            ),
            icon: const Icon(Icons.check, size: 18, color: KColors.success),
            label: const Text('Accept'),
          ),
        ),
      );
      actions.add(KSpacing.hGapSm);
      actions.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _runAction(
              context,
              ref,
              label: 'Declined',
              action: (repo) => repo.declineEstimate(estimateId),
            ),
            icon: const Icon(Icons.close, size: 18, color: KColors.error),
            label: const Text('Decline'),
          ),
        ),
      );
    }

    if (status == 'ACCEPTED') {
      actions.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _convertToInvoice(context, ref),
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('Convert to Invoice'),
          ),
        ),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            KSpacing.md, KSpacing.sm, KSpacing.md, KSpacing.md),
        child: Row(children: actions),
      ),
    );
  }

  Future<void> _runAction(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required Future<void> Function(EstimateRepository repo) action,
  }) async {
    try {
      await action(ref.read(estimateRepositoryProvider));
      ref.invalidate(estimateDetailProvider(estimateId));
      ref.invalidate(estimateListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estimate $label')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _convertToInvoice(
      BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convert to invoice?'),
        content: const Text(
            'A new DRAFT invoice will be created with these line items. '
            'You can review and send it from the invoice screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Convert'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final resp = await ref
          .read(estimateRepositoryProvider)
          .convertToInvoice(estimateId);
      ref.invalidate(estimateDetailProvider(estimateId));
      ref.invalidate(estimateListProvider);
      if (!context.mounted) return;
      final invoiceData = resp['data'] as Map<String, dynamic>?;
      final invoiceId = invoiceData?['id']?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice created as draft')),
      );
      if (invoiceId != null) {
        context.push('/invoices/$invoiceId');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to convert: $e')),
        );
      }
    }
  }
}

class _CommentsTab extends ConsumerStatefulWidget {
  final String estimateId;

  const _CommentsTab({required this.estimateId});

  @override
  ConsumerState<_CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends ConsumerState<_CommentsTab> {
  final _ctrl = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(
        ApiConfig.comments('ESTIMATE', widget.estimateId),
        data: text,
      );
      _ctrl.clear();
      ref.invalidate(_commentsProvider(widget.estimateId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to post: $e')));
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncComments = ref.watch(_commentsProvider(widget.estimateId));

    return Column(
      children: [
        Expanded(
          child: asyncComments.when(
            loading: () => const KLoading(),
            error: (_, __) => KErrorView(
              message: 'Failed to load comments',
              onRetry: () =>
                  ref.invalidate(_commentsProvider(widget.estimateId)),
            ),
            data: (comments) {
              if (comments.isEmpty) {
                return const KEmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: 'No comments yet',
                  subtitle: 'Add a note for your team',
                );
              }
              return ListView.separated(
                padding: KSpacing.pagePadding,
                itemCount: comments.length,
                separatorBuilder: (_, __) => KSpacing.vGapSm,
                itemBuilder: (_, i) => _CommentTile(comment: comments[i]),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                KSpacing.md, KSpacing.sm, KSpacing.md, KSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment…',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _post(),
                  ),
                ),
                KSpacing.hGapSm,
                IconButton.filled(
                  onPressed: _posting ? null : _post,
                  icon: _posting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final text = comment['commentText'] as String? ?? '';
    final isSystem = comment['system'] as bool? ?? false;
    final createdAt = comment['createdAt'] as String?;

    return KCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isSystem ? Icons.auto_awesome_outlined : Icons.person_outline,
            color: isSystem ? KColors.info : KColors.primary,
            size: 18,
          ),
          KSpacing.hGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: KTypography.bodyMedium),
                if (createdAt != null) ...[
                  KSpacing.vGapXs,
                  Text(_formatTime(createdAt),
                      style: KTypography.labelSmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: KSpacing.sm),
        child: Text(title, style: KTypography.h3),
      );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _Row(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: KTypography.bodyMedium),
          KSpacing.hGapMd,
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: bold
                  ? KTypography.labelLarge
                  : KTypography.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
