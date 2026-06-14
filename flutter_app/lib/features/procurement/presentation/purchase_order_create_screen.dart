import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
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
                  Text('Supplier', style: KTypography.h2),
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
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: KColors.primaryLight.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shopping_cart_outlined,
                              color: KColors.primary, size: 20),
                        ),
                        KSpacing.hGapSm,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _supplier?['name']?.toString() ??
                                    'Tap to pick supplier',
                                style: KTypography.labelLarge,
                              ),
                              if (_supplier?['gstin'] != null &&
                                  (_supplier!['gstin'] as String).isNotEmpty)
                                Text('GSTIN: ${_supplier!['gstin']}',
                                    style: KTypography.bodySmall),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: KColors.textHint),
                      ],
                    ),
                  ),
                  KSpacing.vGapMd,

                  // ── Dates ──
                  Text('Order Details', style: KTypography.labelLarge),
                  KSpacing.vGapSm,
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final fields = [
                        KDatePicker(
                          label: 'Order Date',
                          value: _orderDate,
                          onChanged: (d) => setState(() => _orderDate = d),
                        ),
                        KDatePicker(
                          label: 'Expected Delivery (optional)',
                          value: _expectedDeliveryDate ??
                              _orderDate.add(const Duration(days: 7)),
                          onChanged: (d) =>
                              setState(() => _expectedDeliveryDate = d),
                        ),
                      ];
                      if (constraints.maxWidth < 720) {
                        return Column(
                          children: [
                            for (var i = 0; i < fields.length; i++) ...[
                              fields[i],
                              if (i != fields.length - 1) KSpacing.vGapSm,
                            ],
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < fields.length; i++) ...[
                            Expanded(child: fields[i]),
                            if (i != fields.length - 1) KSpacing.hGapSm,
                          ],
                        ],
                      );
                    },
                  ),
                  KSpacing.vGapMd,

                  // ── Line Items ──
                  Text('Items to Order', style: KTypography.h2),
                  KSpacing.vGapMd,
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
                  KSpacing.vGapMd,
                  KButton(
                    label: 'Add Line Item',
                    icon: Icons.add,
                    variant: KButtonVariant.outlined,
                    onPressed: () => setState(() => _lines.add(_PoLine())),
                  ),
                  KSpacing.vGapLg,

                  // ── Running total ──
                  KCard(
                    child: Column(
                      children: [
                        _SummaryRow(
                          label: 'Total',
                          value: CurrencyFormatter.formatIndian(_grandTotal),
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                  KSpacing.vGapMd,

                  // ── Notes ──
                  KTextField(
                    label: 'Notes (optional)',
                    controller: _notesCtl,
                    maxLines: 3,
                  ),
                  KSpacing.vGapLg,
                ],
              ),
            ),
          ),

          // ── Bottom bar ──
          Container(
            padding: const EdgeInsets.all(KSpacing.md),
            decoration: BoxDecoration(
              color: KColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Total', style: KTypography.bodySmall),
                      Text(
                        CurrencyFormatter.formatIndian(_grandTotal),
                        style: KTypography.amountLarge,
                      ),
                    ],
                  ),
                  const Spacer(),
                  KButton(
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
              Text('Line ${widget.index + 1}', style: KTypography.labelLarge),
              const Spacer(),
              TextButton.icon(
                onPressed: _pickItem,
                icon: const Icon(Icons.search, size: 16),
                label: Text(isPicked ? 'Change Item' : 'Pick Item'),
              ),
              if (widget.onRemove != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: KColors.error, size: 20),
                  onPressed: widget.onRemove,
                ),
            ],
          ),
          if (isPicked) ...[
            KSpacing.vGapXs,
            Text(widget.line.description, style: KTypography.bodyMedium),
            KSpacing.vGapSm,
            Row(
              children: [
                Expanded(
                  child: KTextField(
                    label: 'Quantity',
                    controller: _qtyCtl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      widget.line.quantity = double.tryParse(v) ?? 0;
                      widget.onChanged();
                    },
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: KTextField.amount(
                    label: 'Unit Price',
                    controller: _priceCtl,
                    onChanged: (v) {
                      widget.line.unitPrice = double.tryParse(v) ?? 0;
                      widget.onChanged();
                    },
                  ),
                ),
              ],
            ),
            KSpacing.vGapSm,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Line Total: ${CurrencyFormatter.formatIndian(widget.line.lineTotal)}',
                  style:
                      KTypography.amountSmall.copyWith(color: KColors.primary),
                ),
              ],
            ),
          ] else ...[
            KSpacing.vGapXs,
            Text('Pick an item to fill in quantity and price',
                style: KTypography.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: bold ? KTypography.labelLarge : KTypography.bodyMedium),
          Text(value,
              style: bold ? KTypography.amountMedium : KTypography.amountSmall),
        ],
      ),
    );
  }
}
