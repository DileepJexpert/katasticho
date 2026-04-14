import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/estimate_repository.dart';

/// Supported status filters — maps to EstimateStatus on the backend.
const _statusFilters = <_StatusFilter>[
  _StatusFilter('All', null),
  _StatusFilter('Draft', 'DRAFT'),
  _StatusFilter('Sent', 'SENT'),
  _StatusFilter('Accepted', 'ACCEPTED'),
  _StatusFilter('Declined', 'DECLINED'),
  _StatusFilter('Invoiced', 'INVOICED'),
];

class _StatusFilter {
  final String label;
  final String? value;
  const _StatusFilter(this.label, this.value);
}

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
      appBar: AppBar(title: const Text('Estimates')),
      body: Column(
        children: [
          // Status filter chip row
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.md, vertical: KSpacing.sm),
              scrollDirection: Axis.horizontal,
              itemCount: _statusFilters.length,
              separatorBuilder: (_, __) => KSpacing.hGapSm,
              itemBuilder: (_, i) {
                final f = _statusFilters[i];
                final selected = _status == f.value;
                return FilterChip(
                  label: Text(f.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _status = f.value),
                );
              },
            ),
          ),
          const Divider(height: 1),
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
