import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import '../data/franchise_repository.dart';

class BranchPriceOverrideScreen extends ConsumerStatefulWidget {
  const BranchPriceOverrideScreen({super.key});

  @override
  ConsumerState<BranchPriceOverrideScreen> createState() => _BranchPriceOverrideScreenState();
}

class _BranchPriceOverrideScreenState extends ConsumerState<BranchPriceOverrideScreen> {
  String? _selectedBranchId;

  void _showSetOverrideDialog(Map<String, dynamic> item) {
    final priceCtrl = TextEditingController(text: item['customSellingPrice']?.toString() ?? item['masterSellingPrice']?.toString() ?? '');
    final mrpCtrl = TextEditingController(text: item['customMrp']?.toString() ?? item['masterMrp']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Price Override: ${item['itemName']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Master HQ Price: ₹${item['masterSellingPrice']} • Master MRP: ₹${item['masterMrp']}',
                style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
            KSpacing.vGapMd,
            KTextField.amount(label: 'Custom Store Selling Price (₹)', controller: priceCtrl, isRequired: true),
            KSpacing.vGapSm,
            KTextField.amount(label: 'Custom Store MRP (₹)', controller: mrpCtrl),
          ],
        ),
        actions: [
          KButton.secondary(label: 'Cancel', onPressed: () => Navigator.pop(ctx)),
          KButton.primary(
            label: 'Save Price',
            onPressed: () async {
              final price = double.tryParse(priceCtrl.text.trim());
              if (price == null || price <= 0) return;
              try {
                await ref.read(franchiseRepositoryProvider).savePriceOverride({
                  'branchId': _selectedBranchId,
                  'itemId': item['itemId'],
                  'customSellingPrice': price,
                  'customMrp': double.tryParse(mrpCtrl.text.trim()),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (_selectedBranchId != null) {
                  ref.invalidate(branchPriceOverridesProvider(_selectedBranchId!));
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nodesAsync = ref.watch(franchiseNodesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store-Specific Price Overrides'),
      ),
      body: nodesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading stores: $err')),
        data: (nodes) {
          if (nodes.isEmpty) {
            return const Center(child: Text('No franchise stores available.'));
          }

          _selectedBranchId ??= (nodes.first['branchId'] ?? nodes.first['id']).toString();

          final overridesAsync = ref.watch(branchPriceOverridesProvider(_selectedBranchId!));

          return SingleChildScrollView(
            padding: KSpacing.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Store Selector
                KCard(
                  child: Row(
                    children: [
                      const Text('Select Store Location:', style: TextStyle(fontWeight: FontWeight.w600)),
                      KSpacing.hGapMd,
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedBranchId,
                          decoration: const InputDecoration(isDense: true),
                          items: nodes.map((n) {
                            final bId = (n['branchId'] ?? n['id']).toString();
                            return DropdownMenuItem(
                              value: bId,
                              child: Text('${n['nodeName']} (${n['nodeCode']})'),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedBranchId = v),
                        ),
                      ),
                    ],
                  ),
                ),
                KSpacing.vGapLg,

                Text('Store Catalog & Price Adjustments', style: KTypography.h3),
                KSpacing.vGapSm,

                overridesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error loading overrides: $err')),
                  data: (overrides) {
                    if (overrides.isEmpty) {
                      return const KCard(
                        child: KEmptyState(
                          icon: Icons.price_change_outlined,
                          title: 'All items on standard HQ pricing',
                          subtitle: 'No custom regional price overrides set for this store.',
                        ),
                      );
                    }

                    return KCard(
                      padding: EdgeInsets.zero,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('SKU')),
                          DataColumn(label: Text('Item Name')),
                          DataColumn(label: Text('Master Price')),
                          DataColumn(label: Text('Master MRP')),
                          DataColumn(label: Text('Store Override Price')),
                          DataColumn(label: Text('Margin Delta')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: overrides.map((o) {
                          final marginDelta = (o['effectiveMarginPercent'] as num?)?.toDouble() ?? 0;
                          return DataRow(
                            cells: [
                              DataCell(Text(o['itemSku'] ?? '--', style: KTypography.mono())),
                              DataCell(Text(o['itemName'] ?? 'Item')),
                              DataCell(KMoney((o['masterSellingPrice'] as num?)?.toDouble() ?? 0)),
                              DataCell(KMoney((o['masterMrp'] as num?)?.toDouble() ?? 0)),
                              DataCell(KMoney((o['customSellingPrice'] as num?)?.toDouble() ?? 0,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: KColors.primary))),
                              DataCell(
                                KStatusChip(
                                  status: '${marginDelta >= 0 ? '+' : ''}${marginDelta.toStringAsFixed(1)}%',
                                  dense: true,
                                ),
                              ),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () => _showSetOverrideDialog(o),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}