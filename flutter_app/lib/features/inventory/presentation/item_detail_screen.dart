import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/batch_repository.dart';
import '../data/bom_repository.dart';
import '../data/item_repository.dart';
import 'item_create_screen.dart';
import 'item_picker_sheet.dart';
import 'stock_adjust_sheet.dart';

class ItemDetailScreen extends ConsumerWidget {
  final String itemId;

  const ItemDetailScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(itemDetailProvider(itemId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () async {
              final data = itemAsync.value;
              if (data == null) return;
              final item = (data['data'] ?? data) as Map<String, dynamic>;
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ItemCreateScreen(itemId: itemId, initial: item),
                ),
              );
              ref.invalidate(itemDetailProvider(itemId));
              ref.invalidate(itemListProvider);
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete item?'),
                    content: const Text(
                        'This will mark the item inactive. Items with stock on hand cannot be deleted.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
                try {
                  await ref.read(itemRepositoryProvider).deleteItem(itemId);
                  ref.invalidate(itemListProvider);
                  if (context.mounted) context.pop();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Delete failed: $e')),
                    );
                  }
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: itemAsync.when(
        loading: () => const KLoading(),
        error: (err, st) {
          debugPrint('[ItemDetailScreen] ERROR: $err\n$st');
          return KErrorView(
            message: 'Failed to load item',
            onRetry: () => ref.invalidate(itemDetailProvider(itemId)),
          );
        },
        data: (raw) {
          final item = (raw['data'] ?? raw) as Map<String, dynamic>;
          return _ItemDetailBody(item: item, itemId: itemId);
        },
      ),
    );
  }
}

class _ItemDetailBody extends ConsumerWidget {
  final Map<String, dynamic> item;
  final String itemId;

  const _ItemDetailBody({required this.item, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = item['name']?.toString() ?? 'Item';
    final sku = item['sku']?.toString() ?? '';
    final barcode = item['barcode']?.toString() ?? '';
    final brand = item['brand']?.toString() ?? '';
    final manufacturer = item['manufacturer']?.toString() ?? '';
    final itemType = item['itemType']?.toString() ?? 'GOODS';
    final trackInventory = item['trackInventory'] as bool? ?? true;
    final trackBatches = item['trackBatches'] as bool? ?? false;
    final onHand = (item['totalOnHand'] as num?)?.toDouble() ?? 0;
    final reorderLevel = (item['reorderLevel'] as num?)?.toDouble() ?? 0;
    final isLowStock = trackInventory && reorderLevel > 0 && onHand <= reorderLevel;
    final isPharmacy = ref.watch(authProvider).industry?.toUpperCase() == 'PHARMACY';

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(itemDetailProvider(itemId));
      },
      child: ListView(
        padding: KSpacing.pagePadding,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: KColors.primaryLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    itemType == 'SERVICE' ? Icons.build : Icons.inventory_2,
                    size: 36,
                    color: KColors.primary,
                  ),
                ),
                KSpacing.vGapSm,
                Text(name, style: KTypography.h1, textAlign: TextAlign.center),
                Text('SKU: $sku', style: KTypography.bodySmall),
                if (barcode.isNotEmpty)
                  Text('Barcode: $barcode', style: KTypography.bodySmall),
                if (brand.isNotEmpty || manufacturer.isNotEmpty)
                  Text(
                    [if (brand.isNotEmpty) brand, if (manufacturer.isNotEmpty) manufacturer].join(' · '),
                    style: KTypography.bodySmall,
                  ),
              ],
            ),
          ),
          KSpacing.vGapLg,

          // Stock summary
          if (trackInventory) ...[
            KCard(
              title: 'Stock',
              action: KButton(
                label: 'Adjust',
                icon: Icons.tune,
                variant: KButtonVariant.outlined,
                size: KButtonSize.small,
                onPressed: () => _openAdjustSheet(context, ref),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('On Hand', style: KTypography.labelSmall),
                          KSpacing.vGapXs,
                          Text(
                            _fmtQty(onHand),
                            style: KTypography.h2.copyWith(
                              color: isLowStock ? KColors.warning : null,
                            ),
                          ),
                        ],
                      ),
                      if (isLowStock)
                        const KStatusChip(status: 'OVERDUE', label: 'Low stock'),
                    ],
                  ),
                  KSpacing.vGapMd,
                  KDetailRow(
                    label: 'Reorder Level',
                    value: _fmtQty(reorderLevel),
                  ),
                  KDetailRow(
                    label: 'Reorder Qty',
                    value: _fmtQty((item['reorderQuantity'] as num?)?.toDouble() ?? 0),
                  ),
                ],
              ),
            ),
            KSpacing.vGapMd,
          ],

          // Batches — only for batch-tracked items
          if (trackBatches) ...[
            _BatchesCard(itemId: itemId),
            KSpacing.vGapMd,
          ],

          // Bill of Materials — only for composite items.
          if (itemType == 'COMPOSITE') ...[
            _BomEditorCard(parentId: itemId, parentSku: sku),
            KSpacing.vGapMd,
          ],

          // Pricing
          KCard(
            title: 'Pricing',
            child: Column(
              children: [
                KDetailRow(
                  label: 'Sale Price',
                  value: CurrencyFormatter.formatIndian(
                    (item['salePrice'] as num?)?.toDouble() ?? 0,
                  ),
                ),
                KDetailRow(
                  label: 'Purchase Price',
                  value: CurrencyFormatter.formatIndian(
                    (item['purchasePrice'] as num?)?.toDouble() ?? 0,
                  ),
                ),
                if (item['mrp'] != null) ...[
                  KDetailRow(
                    label: 'MRP',
                    value: CurrencyFormatter.formatIndian(
                      (item['mrp'] as num).toDouble(),
                    ),
                  ),
                  Builder(builder: (_) {
                    final mrp = (item['mrp'] as num).toDouble();
                    final purchase =
                        (item['purchasePrice'] as num?)?.toDouble() ?? 0;
                    if (purchase <= 0 || mrp <= 0) return const SizedBox.shrink();
                    final margin = ((mrp - purchase) / mrp * 100);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const SizedBox(width: 0),
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.trending_up, size: 14,
                                    color: margin >= 0
                                        ? KColors.success
                                        : KColors.error),
                                const SizedBox(width: 4),
                                Text(
                                  'Margin: ${margin.toStringAsFixed(1)}%',
                                  style: KTypography.labelSmall.copyWith(
                                    color: margin >= 0
                                        ? KColors.success
                                        : KColors.error,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                KDetailRow(
                  label: 'GST Rate',
                  value: '${(item['gstRate'] as num?)?.toString() ?? '0'}%',
                ),
                KDetailRow(
                  label: 'HSN Code',
                  value: item['hsnCode']?.toString() ?? '--',
                ),
                KDetailRow(
                  label: 'Unit',
                  value: item['unitOfMeasure']?.toString() ?? 'PCS',
                ),
                if (trackBatches)
                  const KDetailRow(
                    label: 'Batch Tracking',
                    value: 'Enabled (FEFO)',
                  ),
              ],
            ),
          ),
          KSpacing.vGapMd,

          // Physical properties
          if (_hasPhysical(item)) ...[
            KCard(
              title: 'Physical Properties',
              child: Column(
                children: [
                  if (item['weight'] != null)
                    KDetailRow(
                      label: 'Weight',
                      value: '${item['weight']} ${item['weightUnit'] ?? 'kg'}',
                    ),
                  if (item['length'] != null || item['width'] != null || item['height'] != null)
                    KDetailRow(
                      label: 'Dimensions (L×W×H)',
                      value:
                          '${item['length'] ?? '-'} × ${item['width'] ?? '-'} × ${item['height'] ?? '-'}'
                          ' ${item['dimensionUnit'] ?? 'cm'}',
                    ),
                ],
              ),
            ),
            KSpacing.vGapMd,
          ],

          // Vendor
          if (item['preferredVendorName'] != null) ...[
            KCard(
              title: 'Vendor',
              child: KDetailRow(
                label: 'Preferred Vendor',
                value: item['preferredVendorName'].toString(),
              ),
            ),
            KSpacing.vGapMd,
          ],

          // Accounting
          if (_hasAccounting(item)) ...[
            KCard(
              title: 'Accounting',
              child: Column(
                children: [
                  if (item['revenueAccountCode'] != null)
                    KDetailRow(label: 'Revenue Account', value: item['revenueAccountCode'].toString()),
                  if (item['cogsAccountCode'] != null)
                    KDetailRow(label: 'COGS Account', value: item['cogsAccountCode'].toString()),
                  if (item['inventoryAccountCode'] != null)
                    KDetailRow(label: 'Inventory Account', value: item['inventoryAccountCode'].toString()),
                ],
              ),
            ),
            KSpacing.vGapMd,
          ],

          // Pharmacy
          if (isPharmacy && _hasPharmacy(item)) ...[
            KCard(
              title: 'Pharmacy',
              child: Column(
                children: [
                  if ((item['drugSchedule']?.toString() ?? '').isNotEmpty)
                    KDetailRow(label: 'Drug Schedule', value: item['drugSchedule'].toString()),
                  if ((item['composition']?.toString() ?? '').isNotEmpty)
                    KDetailRow(label: 'Composition', value: item['composition'].toString()),
                  if ((item['dosageForm']?.toString() ?? '').isNotEmpty)
                    KDetailRow(label: 'Dosage Form', value: item['dosageForm'].toString()),
                  if ((item['packSize']?.toString() ?? '').isNotEmpty)
                    KDetailRow(label: 'Pack Size', value: item['packSize'].toString()),
                  if ((item['storageCondition']?.toString() ?? '').isNotEmpty)
                    KDetailRow(label: 'Storage', value: item['storageCondition'].toString()),
                  if (item['prescriptionRequired'] == true)
                    const KDetailRow(label: 'Prescription', value: 'Required'),
                ],
              ),
            ),
            KSpacing.vGapMd,
          ],

          // Movements (FutureBuilder, lazy load)
          if (trackInventory) ...[
            Text('Recent Movements', style: KTypography.h3),
            KSpacing.vGapSm,
            _MovementsList(itemId: itemId),
          ],
          KSpacing.vGapXl,
        ],
      ),
    );
  }

  void _openAdjustSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StockAdjustSheet(
        itemId: itemId,
        itemName: item['name']?.toString() ?? 'Item',
        onSaved: () {
          ref.invalidate(itemDetailProvider(itemId));
          ref.invalidate(itemListProvider);
        },
      ),
    );
  }

  static String _fmtQty(double q) {
    if (q == q.truncateToDouble()) return q.toStringAsFixed(0);
    return q.toStringAsFixed(2);
  }

  static bool _hasPhysical(Map<String, dynamic> item) =>
      item['weight'] != null || item['length'] != null || item['width'] != null || item['height'] != null;

  static bool _hasAccounting(Map<String, dynamic> item) =>
      item['revenueAccountCode'] != null || item['cogsAccountCode'] != null || item['inventoryAccountCode'] != null;

  static bool _hasPharmacy(Map<String, dynamic> item) =>
      (item['drugSchedule']?.toString() ?? '').isNotEmpty ||
      (item['composition']?.toString() ?? '').isNotEmpty ||
      (item['dosageForm']?.toString() ?? '').isNotEmpty ||
      (item['packSize']?.toString() ?? '').isNotEmpty ||
      (item['storageCondition']?.toString() ?? '').isNotEmpty ||
      item['prescriptionRequired'] == true;
}

class _MovementsList extends ConsumerWidget {
  final String itemId;
  const _MovementsList({required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ref.read(itemRepositoryProvider).getItemMovements(itemId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: KShimmerCard(height: 120),
          );
        }
        if (snapshot.hasError) {
          return KCard(
            child: Text(
              'Failed to load movements: ${snapshot.error}',
              style: KTypography.bodySmall,
            ),
          );
        }
        final raw = snapshot.data;
        final content = raw == null ? null : (raw['data'] ?? raw);
        final movements = content is List
            ? content
            : (content is Map ? (content['content'] as List?) ?? [] : []);

        if (movements.isEmpty) {
          return KCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'No stock movements yet',
                  style: KTypography.bodySmall,
                ),
              ),
            ),
          );
        }
        return KCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < movements.length && i < 20; i++) ...[
                if (i > 0) const Divider(height: 1),
                _MovementTile(movement: movements[i] as Map<String, dynamic>),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MovementTile extends StatelessWidget {
  final Map<String, dynamic> movement;
  const _MovementTile({required this.movement});

  @override
  Widget build(BuildContext context) {
    final type = movement['movementType']?.toString() ?? '';
    final qty = (movement['quantity'] as num?)?.toDouble() ?? 0;
    final date = movement['movementDate']?.toString() ?? '';
    final note = movement['notes']?.toString() ?? '';
    final reversed = movement['reversed'] as bool? ?? false;
    final isPositive = qty > 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: (isPositive ? KColors.success : KColors.error)
            .withValues(alpha: 0.15),
        child: Icon(
          isPositive ? Icons.arrow_upward : Icons.arrow_downward,
          size: 16,
          color: isPositive ? KColors.success : KColors.error,
        ),
      ),
      title: Text(
        type.replaceAll('_', ' '),
        style: KTypography.labelMedium.copyWith(
          decoration: reversed ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        [date, if (note.isNotEmpty) note].join(' • '),
        style: KTypography.bodySmall,
      ),
      trailing: Text(
        '${isPositive ? '+' : ''}${qty.toStringAsFixed(qty == qty.truncateToDouble() ? 0 : 2)}',
        style: KTypography.amountSmall.copyWith(
          color: isPositive ? KColors.success : KColors.error,
        ),
      ),
    );
  }
}

class _BatchesCard extends ConsumerWidget {
  final String itemId;
  const _BatchesCard({required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.read(batchRepositoryProvider).allForItem(itemId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const KCard(
            title: 'Batches',
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: KShimmerCard(height: 80),
            ),
          );
        }
        final batches = snapshot.data ?? [];
        if (batches.isEmpty) {
          return KCard(
            title: 'Batches',
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('No batches received yet',
                    style: KTypography.bodySmall),
              ),
            ),
          );
        }

        return KCard(
          title: 'Batches (${batches.length})',
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < batches.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _BatchRow(batch: batches[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BatchRow extends StatelessWidget {
  final Map<String, dynamic> batch;
  const _BatchRow({required this.batch});

  @override
  Widget build(BuildContext context) {
    final batchNumber = batch['batchNumber']?.toString() ?? '';
    final mfgDate = batch['manufacturingDate']?.toString() ?? '';
    final expiryDate = batch['expiryDate']?.toString() ?? '';
    final qty = (batch['quantityAvailable'] as num?)?.toDouble() ?? 0;

    _BatchStatus status = _BatchStatus.ok;
    if (expiryDate.isNotEmpty) {
      final expiry = DateTime.tryParse(expiryDate);
      if (expiry != null) {
        final daysUntil = expiry.difference(DateTime.now()).inDays;
        if (daysUntil < 0) {
          status = _BatchStatus.expired;
        } else if (daysUntil <= 30) {
          status = _BatchStatus.expiringSoon;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(batchNumber, style: KTypography.labelMedium),
                if (mfgDate.isNotEmpty || expiryDate.isNotEmpty)
                  Text(
                    [
                      if (mfgDate.isNotEmpty) 'Mfg: $mfgDate',
                      if (expiryDate.isNotEmpty) 'Exp: $expiryDate',
                    ].join(' · '),
                    style: KTypography.bodySmall.copyWith(
                      color: status == _BatchStatus.expired
                          ? KColors.error
                          : status == _BatchStatus.expiringSoon
                              ? KColors.warning
                              : null,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              _fmtQty(qty),
              textAlign: TextAlign.right,
              style: KTypography.amountSmall,
            ),
          ),
          const SizedBox(width: 8),
          _statusBadge(status),
        ],
      ),
    );
  }

  Widget _statusBadge(_BatchStatus status) {
    switch (status) {
      case _BatchStatus.ok:
        return const Text('✅', style: TextStyle(fontSize: 14));
      case _BatchStatus.expiringSoon:
        return const Text('🟡', style: TextStyle(fontSize: 14));
      case _BatchStatus.expired:
        return const Text('🔴', style: TextStyle(fontSize: 14));
    }
  }

  static String _fmtQty(double q) {
    if (q == q.truncateToDouble()) return q.toStringAsFixed(0);
    return q.toStringAsFixed(2);
  }
}

enum _BatchStatus { ok, expiringSoon, expired }

/// Bill of Materials editor for a composite (kit) item. Watches
/// `bomComponentsProvider` and renders one row per child with a delete
/// button; the "Add component" button opens the item picker filtered to
/// the eligible children. Backend errorCodes (BOM_DUPLICATE_CHILD,
/// BOM_NESTED_NOT_SUPPORTED, BOM_BATCH_CHILD_NOT_SUPPORTED, BOM_SELF_REFERENCE)
/// are translated to friendly messages in [_snackError].
class _BomEditorCard extends ConsumerWidget {
  final String parentId;
  final String parentSku;

  const _BomEditorCard({required this.parentId, required this.parentSku});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(bomComponentsProvider(parentId));

    return KCard(
      title: 'Bill of Materials',
      subtitle: 'Selling this kit deducts each component',
      action: KButton(
        label: 'Add',
        icon: Icons.add,
        variant: KButtonVariant.outlined,
        size: KButtonSize.small,
        onPressed: () => _openAddSheet(context, ref),
      ),
      child: rowsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: KShimmerCard(height: 60),
        ),
        error: (err, st) {
          debugPrint('[BomEditorCard] ERROR: $err\n$st');
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Failed to load components: $err',
              style: KTypography.bodySmall,
            ),
          );
        },
        data: (rows) {
          if (rows.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No components yet. Add the items this kit is made of.',
                style: KTypography.bodySmall,
              ),
            );
          }
          return Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _BomRow(
                  row: rows[i],
                  onDelete: () => _deleteComponent(context, ref, rows[i]),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _openAddSheet(BuildContext context, WidgetRef ref) async {
    final child = await showItemPicker(context);
    if (child == null) return;
    if (!context.mounted) return;

    // Client-side preflight — the backend re-validates, but catching
    // the obvious cases here gives an immediate error without a round-trip.
    final childId = child['id']?.toString();
    if (childId == null || childId.isEmpty) return;
    if (childId == parentId) {
      _snackError(context, 'A kit cannot contain itself');
      return;
    }
    if (child['itemType']?.toString() == 'COMPOSITE') {
      _snackError(context, 'Nested kits are not supported — pick a simple goods item');
      return;
    }
    if (child['trackBatches'] == true) {
      _snackError(
        context,
        'Batch-tracked items cannot be used as kit components',
      );
      return;
    }

    final qty = await _promptQuantity(context, child);
    if (qty == null || qty <= 0) return;
    if (!context.mounted) return;

    try {
      await ref.read(bomRepositoryProvider).addComponent(
            parentId,
            childItemId: childId,
            quantity: qty,
          );
      ref.invalidate(bomComponentsProvider(parentId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Component added')),
      );
    } catch (e, st) {
      debugPrint('[BomEditorCard] add FAILED: $e\n$st');
      if (!context.mounted) return;
      _snackError(context, _translateError(e, 'Failed to add component'));
    }
  }

  Future<double?> _promptQuantity(
    BuildContext context,
    Map<String, dynamic> child,
  ) {
    final controller = TextEditingController(text: '1');
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quantity of ${child['sku'] ?? ''}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(child['name']?.toString() ?? '', style: KTypography.bodySmall),
            KSpacing.vGapMd,
            KTextField(
              label: 'Quantity per kit',
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              prefixIcon: Icons.numbers,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              Navigator.pop(ctx, v);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteComponent(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> row,
  ) async {
    final componentId = row['id']?.toString();
    if (componentId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove component?'),
        content: Text(
          '${row['childSku'] ?? ''} will be removed from $parentSku.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;

    try {
      await ref.read(bomRepositoryProvider).deleteComponent(componentId);
      ref.invalidate(bomComponentsProvider(parentId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Component removed')),
      );
    } catch (e, st) {
      debugPrint('[BomEditorCard] delete FAILED: $e\n$st');
      if (!context.mounted) return;
      _snackError(context, _translateError(e, 'Failed to remove component'));
    }
  }

  void _snackError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: KColors.error,
      ),
    );
  }

  /// Unwraps a DioException to surface the backend errorCode as a
  /// user-friendly message. Everything else falls back to [fallback].
  String _translateError(Object e, String fallback) {
    if (e is DioException) {
      final data = e.response?.data;
      final code = data is Map ? data['errorCode']?.toString() : null;
      switch (code) {
        case 'BOM_DUPLICATE_CHILD':
          return 'That component is already in the kit — edit the existing row instead.';
        case 'BOM_NESTED_NOT_SUPPORTED':
          return 'Nested kits are not supported — pick a simple goods item.';
        case 'BOM_BATCH_CHILD_NOT_SUPPORTED':
          return 'Batch-tracked items cannot be used as kit components.';
        case 'BOM_SELF_REFERENCE':
          return 'A kit cannot contain itself.';
        case 'BOM_PARENT_NOT_COMPOSITE':
          return 'This item is not a composite — change its type first.';
        case 'BOM_QUANTITY_INVALID':
          return 'Quantity must be greater than zero.';
      }
      final msg = data is Map ? data['message']?.toString() : null;
      if (msg != null && msg.isNotEmpty) return msg;
    }
    return '$fallback: $e';
  }
}

class _BomRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onDelete;

  const _BomRow({required this.row, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final sku = row['childSku']?.toString() ?? '';
    final name = row['childName']?.toString() ?? '';
    final qty = (row['quantity'] as num?)?.toDouble() ?? 0;
    final qtyText =
        qty == qty.truncateToDouble() ? qty.toStringAsFixed(0) : qty.toStringAsFixed(2);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: KColors.primaryLight.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.inventory_2_outlined,
            color: KColors.primary, size: 20),
      ),
      title: Text(sku, style: KTypography.labelLarge),
      subtitle: Text(name, style: KTypography.bodySmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('× $qtyText', style: KTypography.amountSmall),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
