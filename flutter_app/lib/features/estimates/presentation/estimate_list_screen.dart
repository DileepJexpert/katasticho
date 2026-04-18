import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/estimate_repository.dart';

const _statusTabs = [
  KListTab(label: 'All'),
  KListTab(label: 'Draft', value: 'DRAFT'),
  KListTab(label: 'Sent', value: 'SENT'),
  KListTab(label: 'Accepted', value: 'ACCEPTED'),
  KListTab(label: 'Declined', value: 'DECLINED'),
  KListTab(label: 'Invoiced', value: 'INVOICED'),
];

class EstimateListScreen extends ConsumerStatefulWidget {
  const EstimateListScreen({super.key});

  @override
  ConsumerState<EstimateListScreen> createState() => _EstimateListScreenState();
}

class _EstimateListScreenState extends ConsumerState<EstimateListScreen> {
  String? _status;
  final Set<String> _selectedIds = {};

  void _toggleSelect(String id) => setState(() {
        _selectedIds.contains(id)
            ? _selectedIds.remove(id)
            : _selectedIds.add(id);
      });

  void _clearSelection() => setState(_selectedIds.clear);

  Future<void> _bulkSend() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Send $count estimate${count == 1 ? '' : 's'}?'),
        content: const Text('Selected estimates will be marked as sent and emailed to contacts.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Go Back')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repo = ref.read(estimateRepositoryProvider);
    final ids = _selectedIds.toList();
    try {
      final result = await repo.bulkSend(ids);
      if (!mounted) return;
      setState(_selectedIds.clear);
      ref.invalidate(estimateListProvider(EstimateFilters(status: _status)));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_bulkMsg(result, 'Sent'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error));
    }
  }

  Future<void> _bulkDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count estimate${count == 1 ? '' : 's'}?'),
        content: const Text('Only DRAFT estimates can be deleted. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: KColors.error.withValues(alpha: 0.12),
              foregroundColor: KColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repo = ref.read(estimateRepositoryProvider);
    final filters = EstimateFilters(status: _status);
    final ids = _selectedIds.toList();
    try {
      final result = await repo.bulkDelete(ids);
      if (!mounted) return;
      setState(_selectedIds.clear);
      ref.invalidate(estimateListProvider(filters));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_bulkMsg(result, 'Deleted'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error));
    }
  }

  String _bulkMsg(Map<String, dynamic> result, String verb) {
    final data = (result['data'] as Map?) ?? {};
    final success = (data['successCount'] as num?)?.toInt() ?? 0;
    final fail = (data['failCount'] as num?)?.toInt() ?? 0;
    if (fail == 0) return '$verb $success successfully';
    return '$verb $success, $fail failed';
  }

  @override
  Widget build(BuildContext context) {
    final filters = EstimateFilters(status: _status);
    final asyncEstimates = ref.watch(estimateListProvider(filters));
    final inSelection = _selectedIds.isNotEmpty;

    return Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Estimates',
            searchHint: 'Search estimates…',
            tabs: _statusTabs,
            selectedTab: _status,
            onTabChanged: (v) => setState(() => _status = v),
            selectionCount: _selectedIds.length,
            onClearSelection: _clearSelection,
            selectionActions: [
              IconButton(
                icon: const Icon(Icons.send_outlined, size: 20),
                tooltip: 'Send selected',
                visualDensity: VisualDensity.compact,
                onPressed: _bulkSend,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                tooltip: 'Delete selected',
                color: KColors.error,
                visualDensity: VisualDensity.compact,
                onPressed: _bulkDelete,
              ),
            ],
          ),
          Expanded(
            child: asyncEstimates.when(
              loading: () => const KShimmerList(),
              error: (err, _) => KErrorView(
                message: 'Failed to load estimates',
                onRetry: () => ref.invalidate(estimateListProvider(filters)),
              ),
              data: (data) {
                final content = data['data'];
                final estimates = content is List
                    ? content
                    : (content is Map
                        ? (content['content'] as List?) ?? []
                        : []);

                if (estimates.isEmpty) {
                  return KEmptyState(
                    icon: Icons.request_quote_outlined,
                    title: 'No estimates yet',
                    subtitle: 'Create a quote for your customer',
                    actionLabel: 'New Estimate',
                    onAction: () => context.push('/estimates/create'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(estimateListProvider(filters)),
                  child: ListView.separated(
                    padding: KSpacing.pagePadding,
                    itemCount: estimates.length,
                    separatorBuilder: (_, __) => KSpacing.vGapSm,
                    itemBuilder: (context, i) {
                      final est = estimates[i] as Map<String, dynamic>;
                      final id = est['id']?.toString() ?? '';
                      return _EstimateCard(
                        estimate: est,
                        selected: _selectedIds.contains(id),
                        inSelection: inSelection,
                        onToggleSelect: () => _toggleSelect(id),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: inSelection
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/estimates/create'),
              icon: const Icon(Icons.add),
              label: const Text('New Estimate'),
            ),
    );
  }
}

class _EstimateCard extends StatelessWidget {
  final Map<String, dynamic> estimate;
  final bool selected;
  final bool inSelection;
  final VoidCallback onToggleSelect;

  const _EstimateCard({
    required this.estimate,
    required this.selected,
    required this.inSelection,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final id = estimate['id']?.toString();
    final number = estimate['estimateNumber'] as String? ?? '';
    final contactName = estimate['contactName'] as String? ?? '—';
    final subject = estimate['subject'] as String?;
    final total = (estimate['total'] as num?)?.toDouble() ?? 0;
    final status = estimate['status'] as String? ?? 'DRAFT';
    final date = estimate['estimateDate'] as String? ?? '';

    final statusColor = _statusColor(status);

    return KCard(
      onTap: () {
        if (inSelection) {
          onToggleSelect();
          return;
        }
        if (id != null) context.push('/estimates/$id');
      },
      onLongPress: onToggleSelect,
      borderColor: selected ? cs.primary : null,
      backgroundColor: selected ? cs.primary.withValues(alpha: 0.06) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: inSelection
                ? Center(
                    child: Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected ? cs.primary : cs.onSurfaceVariant,
                      size: 24,
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.request_quote_outlined,
                        color: statusColor, size: 20),
                  ),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        number,
                        style: KTypography.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('₹${total.toStringAsFixed(0)}',
                        style: KTypography.labelLarge),
                  ],
                ),
                KSpacing.vGapXs,
                Text(
                  contactName,
                  style: KTypography.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subject != null && subject.isNotEmpty) ...[
                  KSpacing.vGapXs,
                  Text(
                    subject,
                    style: KTypography.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                KSpacing.vGapXs,
                Row(
                  children: [
                    Expanded(
                      child: Text(_formatDate(date),
                          style: KTypography.labelSmall),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style:
                            KTypography.labelSmall.copyWith(color: statusColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
}
