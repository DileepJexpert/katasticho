import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../../inventory/presentation/item_picker_sheet.dart';
import '../data/purchase_order_repository.dart';
import 'supplier_picker_sheet.dart';

class PurchaseOrderPrefill {
  final List<Map<String, dynamic>>? items;

  const PurchaseOrderPrefill({this.items});
}

class PurchaseOrderCreateScreen extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>>? prefillItems;

  const PurchaseOrderCreateScreen({super.key, this.prefillItems});

  @override
  ConsumerState<PurchaseOrderCreateScreen> createState() =>
      _PurchaseOrderCreateScreenState();
}

class _PurchaseOrderCreateScreenState
    extends ConsumerState<PurchaseOrderCreateScreen> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Map<String, dynamic>? _supplier;
  DateTime _orderDate = DateTime.now();
  DateTime? _expectedDeliveryDate;
  final _notesCtl = TextEditingController();

  List<_PoLine> _lines = [_PoLine()];

  @override
  void initState() {
    super.initState();
    _prefillFromSource();
  }

  void _prefillFromSource() {
    final items = widget.prefillItems;
    if (items == null || items.isEmpty) return;

    final prefilled = items.map((item) {
      final line = _PoLine();
      line.itemId = item['itemId']?.toString() ?? item['id']?.toString();
      line.description = item['itemName']?.toString() ??
          item['name']?.toString() ??
          item['description']?.toString() ??
          '';
      line.quantity = (item['suggestOrderQty'] as num?)?.toDouble() ??
          (item['quantity'] as num?)?.toDouble() ??
          1;
      line.unitPrice = (item['unitPrice'] as num?)?.toDouble() ??
          (item['purchasePrice'] as num?)?.toDouble() ??
          (item['averageCost'] as num?)?.toDouble() ??
          0;
      line.taxGroupId = item['taxGroupId']?.toString();
      return line;
    }).where((line) => line.itemId != null).toList();

    if (prefilled.isNotEmpty) {
      _lines = prefilled;
    }
  }

  @override
  void dispose() {
    _notesCtl.dispose();
    super.dispose();
  }

  double get _grandTotal => _lines.fold(0, (sum, l) => sum + l.lineTotal);

  Future<void> _pickSupplier() async {
    final picked = await showSupplierPicker(context);
    if (picked != null) {
      setState(() => _supplier = picked);
    }
  }

  Future<void> _submit() async {
    if (_supplier == null) {
      setState(() => _errorMessage = 'Please select a supplier');
      return;
    }
    final validLines = _lines.where((l) => l.itemId != null).toList();
    if (validLines.isEmpty) {
      setState(() => _errorMessage = 'Add at least one line item');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(purchaseOrderRepositoryProvider);
      final body = <String, dynamic>{
        'supplierId': _supplier!['id'],
        'orderDate': _orderDate.toIso8601String().split('T').first,
        if (_expectedDeliveryDate != null)
          'expectedDeliveryDate':
              _expectedDeliveryDate!.toIso8601String().split('T').first,
        if (_notesCtl.text.trim().isNotEmpty) 'notes': _notesCtl.text.trim(),
        'lines': validLines
            .map((l) => {
                  'itemId': l.itemId,
                  'description': l.description,
                  'quantity': l.quantity,
                  'unitPrice': l.unitPrice,
                  if (l.taxGroupId != null) 'taxGroupId': l.taxGroupId,
                })
            .toList(),
      };
      final result = await repo.createPO(body);
      final created = (result['data'] ?? result) as Map<String, dynamic>;
      final id = created['id']?.toString();
      ref.invalidate(purchaseOrdersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase order saved as draft')),
        );
        if (id != null) {
          context.go('/purchase-orders/$id');
        } else {
          context.go(Routes.purchaseOrders);
        }
      }
    } catch (e, st) {
      debugPrint('[POCreate] save FAILED: $e\n$st');
      String msg = 'Failed to create purchase order';
      if (e is DioException) {
        final body = e.response?.data;
        if (body is Map) {
          msg = body['message'] as String? ?? body['error'] as String? ?? msg;
        }
      }
      setState(() => _errorMessage = msg);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KKeyboardFormWrapper(
      onSubmit: _submit,
      onCancel: () => context.go(Routes.purchaseOrders),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New Purchase Order'),
          leading: IconButton(
            tooltip: 'Back to purchase orders',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(Routes.purchaseOrders),
          ),
        ),
        body: Column(
          children: [
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: KErrorBanner(
                  message: _errorMessage!,
                  onDismiss: () => setState(() => _errorMessage = null),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: KSpacing.pagePadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Supplier ──
                    Text('Supplier', style: KTypography.titleLarge),
                    KSpacing.vGapSm,
                    KCard(
                      onTap: _pickSupplier,
                      padding: const EdgeInsets.symmetric(
                        horizontal: KSpacing.md,
                        vertical: KSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: KColors.primarySoft,
                              borderRadius: KSpacing.borderRadiusSm,
                            ),
                            child: const Icon(Icons.local_shipping_outlined,
                                color: KColors.primary, size: 22),
                          ),
                          KSpacing.hGapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _supplier?['name']?.toString() ??
                                      'Select Supplier (Vendor)',
                                  style: KTypography.titleMedium.copyWith(
                                    color: _supplier == null
                                        ? KColors.primary
                                        : null,
                                  ),
                                ),
                                if (_supplier?['gstin'] != null &&
                                    (_supplier!['gstin'] as String).isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'GSTIN: ${_supplier!['gstin']}',
                                      style: KTypography.mono(fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: KColors.textHint),
                        ],
                      ),
                    ),
                    KSpacing.vGapMd,

                    // ── Order Details ──
                    Text('Order Details', style: KTypography.titleLarge),
                    KSpacing.vGapSm,
                    KCompactRow(
                      children: [
                        KDatePicker(
                          label: 'Order Date',
                          value: _orderDate,
                          onChanged: (d) => setState(() => _orderDate = d),
                        ),
                        KDatePicker(
                          label: 'Expected Delivery Date',
                          value: _expectedDeliveryDate ??
                              _orderDate.add(const Duration(days: 7)),
                          onChanged: (d) =>
                              setState(() => _expectedDeliveryDate = d),
                        ),
                      ],
                    ),
                    KSpacing.vGapMd,

                    // ── Line Items ──
                    Row(
                      children: [
                        Text('Items to Order', style: KTypography.titleLarge),
                        const Spacer(),
                        KButton.outlined(
                          label: 'Add Line Item',
                          icon: Icons.add,
                          size: KButtonSize.small,
                          onPressed: () => setState(() => _lines.add(_PoLine())),
                        ),
                      ],
                    ),
                    KSpacing.vGapSm,
                    ...List.generate(_lines.length, (i) {
                      return _PoLineCard(
                        line: _lines[i],
                        index: i,
                        onRemove: _lines.length > 1
                            ? () => setState(() => _lines.removeAt(i))
                            : null,
                        onChanged: () => setState(() {}),
                      );
                    }),
                    KSpacing.vGapLg,

                    // ── Running total ──
                    KCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Estimated Total', style: KTypography.titleMedium),
                          KMoney(
                            _grandTotal,
                            size: KMoneySize.large,
                            style: const TextStyle(
                              color: KColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    KSpacing.vGapMd,

                    // ── Notes ──
                    KTextField(
                      label: 'Notes / Payment Terms (optional)',
                      controller: _notesCtl,
                      maxLines: 3,
                    ),
                    KSpacing.vGapLg,
                  ],
                ),
              ),
            ),

            // ── Sticky Bottom Bar ──
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KSpacing.md,
                vertical: KSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Order Total', style: KTypography.caption),
                        KMoney(
                          _grandTotal,
                          size: KMoneySize.medium,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const Spacer(),
                    KButton.outlined(
                      label: 'Cancel',
                      onPressed: () => context.go(Routes.purchaseOrders),
                    ),
                    KSpacing.hGapSm,
                    KButton.primary(
                      label: 'Save as Draft',
                      icon: Icons.save_outlined,
                      onPressed: _submit,
                      isLoading: _isSubmitting,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Models ──

class _PoLine {
  String? itemId;
  String description = '';
  double quantity = 1;
  double unitPrice = 0;
  String? taxGroupId;

  double get lineTotal => quantity * unitPrice;
}

class _PoLineCard extends StatefulWidget {
  final _PoLine line;
  final int index;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _PoLineCard({
    required this.line,
    required this.index,
    this.onRemove,
    required this.onChanged,
  });

  @override
  State<_PoLineCard> createState() => _PoLineCardState();
}

class _PoLineCardState extends State<_PoLineCard> {
  late final TextEditingController _qtyCtl;
  late final TextEditingController _priceCtl;

  @override
  void initState() {
    super.initState();
    _qtyCtl = TextEditingController(text: widget.line.quantity.toString());
    _priceCtl = TextEditingController(text: widget.line.unitPrice.toString());
  }

  @override
  void dispose() {
    _qtyCtl.dispose();
    _priceCtl.dispose();
    super.dispose();
  }

  Future<void> _pickItem() async {
    final picked = await showItemPicker(context);
    if (picked == null) return;
    setState(() {
      widget.line.itemId = picked['id']?.toString();
      widget.line.description = picked['name']?.toString() ?? '';
      widget.line.unitPrice =
          (picked['purchasePrice'] as num?)?.toDouble() ?? 0;
      _priceCtl.text = widget.line.unitPrice.toString();
      widget.line.taxGroupId = picked['defaultTaxGroupId']?.toString();
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final isPicked = widget.line.itemId != null;
    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Line #${widget.index + 1}', style: KTypography.labelLarge),
              const Spacer(),
              KButton.outlined(
                size: KButtonSize.small,
                icon: Icons.search,
                label: isPicked ? 'Change Item' : 'Pick Item',
                onPressed: _pickItem,
              ),
              if (widget.onRemove != null) ...[
                KSpacing.hGapSm,
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: KColors.error, size: 20),
                  onPressed: widget.onRemove,
                ),
              ],
            ],
          ),
          if (isPicked) ...[
            KSpacing.vGapXs,
            Text(widget.line.description,
                style: KTypography.titleMedium),
            KSpacing.vGapSm,
            KCompactRow(
              children: [
                KTextField(
                  label: 'Quantity',
                  controller: _qtyCtl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    widget.line.quantity = double.tryParse(v) ?? 0;
                    widget.onChanged();
                  },
                ),
                KTextField.amount(
                  label: 'Unit Price',
                  controller: _priceCtl,
                  onChanged: (v) {
                    widget.line.unitPrice = double.tryParse(v) ?? 0;
                    widget.onChanged();
                  },
                ),
              ],
            ),
            KSpacing.vGapSm,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Line Total: ', style: KTypography.caption),
                KMoney(
                  widget.line.lineTotal,
                  size: KMoneySize.medium,
                  style: const TextStyle(
                    color: KColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ] else ...[
            KSpacing.vGapXs,
            Text('Pick an item from catalog to fill in quantity and purchase rate',
                style: KTypography.bodySmall.copyWith(color: KColors.textHint)),
          ],
        ],
      ),
    );
  }
}
