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

  @override
  Widget build(BuildContext context) {
    final filters = EstimateFilters(status: _status);
    final asyncEstimates = ref.watch(estimateListProvider(filters));

    return Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Estimates',
            searchHint: 'Search estimates…',
            tabs: _statusTabs,
            selectedTab: _status,
            onTabChanged: (v) => setState(() => _status = v),
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
                    itemBuilder: (context, i) => _EstimateCard(
                      estimate: estimates[i] as Map<String, dynamic>,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/estimates/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Estimate'),
      ),
    );
  }
}

class _EstimateCard extends StatelessWidget {
  final Map<String, dynamic> estimate;

  const _EstimateCard({required this.estimate});

  @override
  Widget build(BuildContext context) {
    final id = estimate['id']?.toString();
    final number = estimate['estimateNumber'] as String? ?? '';
    final contactName = estimate['contactName'] as String? ?? '—';
    final subject = estimate['subject'] as String?;
    final total = (estimate['total'] as num?)?.toDouble() ?? 0;
    final status = estimate['status'] as String? ?? 'DRAFT';
    final date = estimate['estimateDate'] as String? ?? '';

    final statusColor = _statusColor(status);

    return KCard(
      onTap: id != null ? () => context.push('/estimates/$id') : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.request_quote_outlined,
                color: statusColor, size: 20),
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
                      child: Text(
                        _formatDate(date),
                        style: KTypography.labelSmall,
                      ),
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
                        style: KTypography.labelSmall
                            .copyWith(color: statusColor),
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
