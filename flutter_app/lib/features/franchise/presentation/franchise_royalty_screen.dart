import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import '../data/franchise_repository.dart';

class FranchiseRoyaltyScreen extends ConsumerStatefulWidget {
  const FranchiseRoyaltyScreen({super.key});

  @override
  ConsumerState<FranchiseRoyaltyScreen> createState() => _FranchiseRoyaltyScreenState();
}

class _FranchiseRoyaltyScreenState extends ConsumerState<FranchiseRoyaltyScreen> {
  bool _calculating = false;

  void _showCalculateSettlementDialog() {
    final nodes = ref.read(franchiseNodesProvider).valueOrNull ?? [];
    if (nodes.isEmpty) return;

    String selectedNodeId = nodes.first['id'].toString();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Calculate Store Royalty Settlement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedNodeId,
                decoration: const InputDecoration(labelText: 'Franchise Store'),
                items: nodes.map((n) {
                  return DropdownMenuItem(
                    value: n['id'].toString(),
                    child: Text('${n['nodeName']} (${n['nodeCode']})'),
                  );
                }).toList(),
                onChanged: (v) => setDialogState(() => selectedNodeId = v ?? selectedNodeId),
              ),
              KSpacing.vGapMd,
              Text('Settlement Period: Current Month', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
            ],
          ),
          actions: [
            KButton.secondary(label: 'Cancel', onPressed: () => Navigator.pop(ctx)),
            KButton.primary(
              label: 'Calculate Settlement',
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _calculating = true);
                try {
                  final now = DateTime.now();
                  final start = DateTime(now.year, now.month, 1);
                  final end = DateTime(now.year, now.month + 1, 0);

                  final startStr = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
                  final endStr = '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';

                  await ref.read(franchiseRepositoryProvider).calculateSettlement({
                    'franchiseNodeId': selectedNodeId,
                    'periodStart': startStr,
                    'periodEnd': endStr,
                  });
                  ref.invalidate(franchiseSettlementsProvider(null));
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _calculating = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateInvoice(String settlementId) async {
    try {
      await ref.read(franchiseRepositoryProvider).generateRoyaltyInvoice(settlementId);
      ref.invalidate(franchiseSettlementsProvider(null));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Formal royalty invoice generated successfully!'), backgroundColor: KColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settlementsAsync = ref.watch(franchiseSettlementsProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Franchise Royalty & Fee Settlements'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: KButton.primary(
              label: _calculating ? 'Calculating...' : 'Run Monthly Settlement',
              icon: Icons.calculate_outlined,
              onPressed: _calculating ? null : _showCalculateSettlementDialog,
            ),
          ),
        ],
      ),
      body: settlementsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading settlements: $err')),
        data: (settlements) {
          if (settlements.isEmpty) {
            return const Center(
              child: KEmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No settlements generated',
                subtitle: 'Click "Run Monthly Settlement" to calculate turnover royalties.',
              ),
            );
          }

          return SingleChildScrollView(
            padding: KSpacing.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Settlement History & Inter-Company Billing', style: KTypography.h3),
                KSpacing.vGapSm,
                KCard(
                  padding: EdgeInsets.zero,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Store')),
                      DataColumn(label: Text('Period')),
                      DataColumn(label: Text('Gross Sales')),
                      DataColumn(label: Text('Royalty Fee')),
                      DataColumn(label: Text('Fixed Fee')),
                      DataColumn(label: Text('Total Settlement')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: settlements.map((s) {
                      final status = s['status'] ?? 'CALCULATED';
                      final canInvoice = status == 'CALCULATED';
                      return DataRow(
                        cells: [
                          DataCell(Text('${s['nodeName']} (${s['nodeCode']})', style: KTypography.labelMedium)),
                          DataCell(Text('${s['periodStart']} → ${s['periodEnd']}')),
                          DataCell(KMoney((s['grossSalesAmount'] as num?)?.toDouble() ?? 0)),
                          DataCell(Text('₹${s['royaltyAmount']} (${s['royaltyPercent']}%)')),
                          DataCell(KMoney((s['fixedFeeAmount'] as num?)?.toDouble() ?? 0)),
                          DataCell(KMoney((s['totalSettlementAmount'] as num?)?.toDouble() ?? 0,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: KColors.primary))),
                          DataCell(KStatusChip(status: status, dense: true)),
                          DataCell(
                            canInvoice
                                ? KButton.secondary(
                                    label: 'Invoice',
                                    icon: Icons.receipt_long_outlined,
                                    onPressed: () => _generateInvoice(s['id']),
                                  )
                                : const Icon(Icons.check_circle_outline, color: KColors.success, size: 20),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}