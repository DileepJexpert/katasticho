import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/expense_repository.dart';

/// Pulls comments for a given (entityType, entityId).
final _commentsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, expenseId) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiConfig.comments('EXPENSE', expenseId));
  final data = (resp.data as Map<String, dynamic>)['data'];
  if (data is List) return data.cast<Map<String, dynamic>>();
  if (data is Map && data['content'] is List) {
    return (data['content'] as List).cast<Map<String, dynamic>>();
  }
  return const <Map<String, dynamic>>[];
});

class ExpenseDetailScreen extends ConsumerWidget {
  final String expenseId;

  const ExpenseDetailScreen({super.key, required this.expenseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncExpense = ref.watch(expenseDetailProvider(expenseId));

    return asyncExpense.when(
      loading: () => const Scaffold(body: KLoading()),
      error: (_, __) => Scaffold(
        appBar: AppBar(title: const Text('Expense')),
        body: KErrorView(
          message: 'Failed to load expense',
          onRetry: () => ref.invalidate(expenseDetailProvider(expenseId)),
        ),
      ),
      data: (data) {
        final raw = data['data'] ?? data;
        final expense = raw as Map<String, dynamic>;
        final number = expense['expenseNumber'] as String? ?? 'Expense';
        final status = expense['status'] as String? ?? 'RECORDED';

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(number),
              actions: [
                if (status != 'VOID' && status != 'INVOICED')
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'void') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Void expense?'),
                            content: const Text(
                                'This creates a reversal journal entry. The expense record stays for audit.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Void',
                                    style: TextStyle(color: KColors.error)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && context.mounted) {
                          try {
                            await ref
                                .read(expenseRepositoryProvider)
                                .voidExpense(expenseId);
                            ref.invalidate(expenseDetailProvider(expenseId));
                            ref.invalidate(expenseListProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Expense voided')),
                              );
                              context.pop();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed: $e')),
                              );
                            }
                          }
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'void',
                          child: Text('Void expense',
                              style: TextStyle(color: KColors.error))),
                    ],
                  ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Details'),
                  Tab(text: 'Comments'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _DetailsTab(expense: expense),
                _CommentsTab(expenseId: expenseId),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailsTab extends StatelessWidget {
  final Map<String, dynamic> expense;

  const _DetailsTab({required this.expense});

  @override
  Widget build(BuildContext context) {
    final status = expense['status'] as String? ?? 'RECORDED';
    final amount = (expense['amount'] as num?)?.toDouble() ?? 0;
    final taxAmount = (expense['taxAmount'] as num?)?.toDouble() ?? 0;
    final total = (expense['total'] as num?)?.toDouble() ?? 0;
    final gstRate = (expense['gstRate'] as num?)?.toDouble() ?? 0;
    final category = expense['category'] as String?;
    final description = expense['description'] as String?;
    final accountCode = expense['accountCode'] as String?;
    final accountName = expense['accountName'] as String?;
    final paymentMode = expense['paymentMode'] as String? ?? 'CASH';
    final paidThroughName = expense['paidThroughName'] as String?;
    final contactName = expense['contactName'] as String?;
    final date = expense['expenseDate'] as String? ?? '';
    final journalEntryId = expense['journalEntryId']?.toString();
    final billable = expense['billable'] as bool? ?? false;

    final statusColor = switch (status) {
      'VOID' => KColors.error,
      'INVOICED' => KColors.info,
      'BILLABLE' => KColors.warning,
      _ => KColors.success,
    };

    return SingleChildScrollView(
      padding: KSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total amount hero
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
                Text(_formatDate(date), style: KTypography.bodyMedium),
              ],
            ),
          ),
          KSpacing.vGapLg,

          _SectionHeader('Breakdown'),
          _Row('Amount', '₹${amount.toStringAsFixed(2)}'),
          _Row('GST (${gstRate.toInt()}%)',
              '₹${taxAmount.toStringAsFixed(2)}'),
          const Divider(),
          _Row('Total', '₹${total.toStringAsFixed(2)}', bold: true),
          KSpacing.vGapMd,

          _SectionHeader('Classification'),
          if (category != null) _Row('Category', category),
          if (description != null && description.isNotEmpty)
            _Row('Description', description),
          if (accountCode != null)
            _Row('Expense account', '$accountCode — ${accountName ?? ''}'),
          KSpacing.vGapMd,

          _SectionHeader('Payment'),
          _Row('Payment mode', paymentMode),
          if (paidThroughName != null)
            _Row('Paid through', paidThroughName),
          if (contactName != null) _Row('Vendor', contactName),
          if (billable) _Row('Billable', 'Yes'),
          KSpacing.vGapMd,

          if (journalEntryId != null) ...[
            _SectionHeader('Accounting'),
            KCard(
              onTap: () =>
                  context.push('/accounting/journal-entries/$journalEntryId'),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: KColors.primary),
                  KSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Journal entry', style: KTypography.labelLarge),
                        KSpacing.vGapXs,
                        Text(journalEntryId,
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

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _CommentsTab extends ConsumerStatefulWidget {
  final String expenseId;

  const _CommentsTab({required this.expenseId});

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
        ApiConfig.comments('EXPENSE', widget.expenseId),
        data: text,
      );
      _ctrl.clear();
      ref.invalidate(_commentsProvider(widget.expenseId));
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
    final asyncComments = ref.watch(_commentsProvider(widget.expenseId));

    return Column(
      children: [
        Expanded(
          child: asyncComments.when(
            loading: () => const KLoading(),
            error: (_, __) => KErrorView(
              message: 'Failed to load comments',
              onRetry: () =>
                  ref.invalidate(_commentsProvider(widget.expenseId)),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: KTypography.bodyMedium),
          Text(
            value,
            style: bold
                ? KTypography.labelLarge
                : KTypography.bodyMedium,
          ),
        ],
      ),
    );
  }
}
