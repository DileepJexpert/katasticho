import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/form_error_handler.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/workflow/workflow_hint_resolver.dart';
import '../../../routing/app_router.dart';
import '../../inventory/presentation/item_picker_sheet.dart';
import '../../tax_groups/presentation/widgets/tax_group_picker.dart';
import '../data/stock_receipt_repository.dart';
import 'supplier_picker_sheet.dart';

class StockReceiptPrefill {
  final Map<String, dynamic>? supplier;
  final List<Map<String, dynamic>>? items;

  const StockReceiptPrefill({
    this.supplier,
    this.items,
  });
}

class StockReceiptCreateScreen extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>>? prefillItems;
  final Map<String, dynamic>? prefillSupplier;

  const StockReceiptCreateScreen({
    super.key,
    this.prefillItems,
    this.prefillSupplier,
  });

  @override
  ConsumerState<StockReceiptCreateScreen> createState() =>
      _StockReceiptCreateScreenState();
}

class _StockReceiptCreateScreenState
    extends ConsumerState<StockReceiptCreateScreen> with FormErrorHandler {
  bool _isSubmitting = false;
  String? _errorMessage;

  Map<String, dynamic>? _supplier;
  DateTime _receiptDate = DateTime.now();
  DateTime? _supplierInvoiceDate;
  final _supplierInvoiceNoCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  final _freightCtl = TextEditingController();
  final _dutyCtl = TextEditingController();
  final _insuranceCtl = TextEditingController();
  final _otherChargesCtl = TextEditingController();

  final List<_GrnLine> _lines = [_GrnLine()];

  @override
  void initState() {
    super.initState();
    _prefillFromSource();
  }

  void _prefillFromSource() {
    _supplier = widget.prefillSupplier;
    final items = widget.prefillItems;
    if (items == null || items.isEmpty) return;

    final prefilled = items.map((item) {
      final line = _GrnLine();
      line.itemId = item['itemId']?.toString();
      line.description = item['itemName']?.toString() ?? '';
      line.quantity = (item['suggestOrderQty'] as num?)?.toDouble() ?? 1;
      line.unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0;
      return line;
    }).toList();

    if (prefilled.isNotEmpty) {
      _lines.clear();
      _lines.addAll(prefilled);
    }
  }

  @override
  void dispose() {
    _supplierInvoiceNoCtl.dispose();
    _notesCtl.dispose();
    _freightCtl.dispose();
    _dutyCtl.dispose();
    _insuranceCtl.dispose();
    _otherChargesCtl.dispose();
    super.dispose();
  }

  double _chargeOf(TextEditingController c) =>
      double.tryParse(c.text.trim()) ?? 0;

  double get _landedTotal =>
      _chargeOf(_freightCtl) +
      _chargeOf(_dutyCtl) +
      _chargeOf(_insuranceCtl) +
      _chargeOf(_otherChargesCtl);

  double get _subtotal => _lines.fold(0, (sum, l) => sum + l.taxableAmount);
  double get _totalTax => _lines.fold(0, (sum, l) => sum + l.taxAmount);
  double get _grandTotal => _subtotal + _totalTax + _landedTotal;

  Future<void> _pickSupplier() async {
    final picked = await showSupplierPicker(context);
    if (picked != null) {
      setState(() => _supplier = picked);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_supplier == null) {
      setState(() => _errorMessage = 'Please select a supplier');
      return;
    }
    final validLines = _lines.where((l) => l.itemId != null).toList();
    if (validLines.isEmpty) {
      setState(() =>
          _errorMessage = 'Add at least one line item with a picked item');
      return;
    }
    final missingBatch = validLines
        .where((l) => l.trackBatches && l.batchNumber.trim().isEmpty)
        .toList();
    if (missingBatch.isNotEmpty) {
      setState(() => _errorMessage =
          'Batch number is required for: ${missingBatch.map((l) => l.description).join(', ')}');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(stockReceiptRepositoryProvider);
      final body = <String, dynamic>{
        'supplierId': _supplier!['id'],
        'receiptDate': _receiptDate.toIso8601String().split('T').first,
        if (_supplierInvoiceNoCtl.text.trim().isNotEmpty)
          'supplierInvoiceNo': _supplierInvoiceNoCtl.text.trim(),
        if (_supplierInvoiceDate != null)
          'supplierInvoiceDate':
              _supplierInvoiceDate!.toIso8601String().split('T').first,
        if (_notesCtl.text.trim().isNotEmpty) 'notes': _notesCtl.text.trim(),
        if (_chargeOf(_freightCtl) > 0) 'freightAmount': _chargeOf(_freightCtl),
        if (_chargeOf(_dutyCtl) > 0) 'dutyAmount': _chargeOf(_dutyCtl),
        if (_chargeOf(_insuranceCtl) > 0)
          'insuranceAmount': _chargeOf(_insuranceCtl),
        if (_chargeOf(_otherChargesCtl) > 0)
          'otherCharges': _chargeOf(_otherChargesCtl),
        'lines': validLines
            .map((l) => {
                  'itemId': l.itemId,
                  'description': l.description,
                  'quantity': l.quantity,
                  'unitPrice': l.unitPrice,
                  'gstRate': l.gstRate,
                  if (l.taxGroupId != null) 'taxGroupId': l.taxGroupId,
                  if (l.batchNumber.isNotEmpty) 'batchNumber': l.batchNumber,
                  if (l.expiryDate != null)
                    'expiryDate':
                        l.expiryDate!.toIso8601String().split('T').first,
                })
            .toList(),
      };
      final result = await repo.createReceipt(body);
      final created = (result['data'] ?? result) as Map<String, dynamic>;
      final id = created['id']?.toString();
      ref.invalidate(stockReceiptListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goods receipt saved as draft')),
        );
        if (id != null) {
          context.go('/stock-receipts/$id');
        } else {
          context.go(Routes.stockReceipts);
        }
      }
    } catch (e, st) {
      debugPrint('[GrnCreate] save FAILED: $e\n$st');
      String msg = 'Failed to create goods receipt';
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
    final auth = ref.watch(authProvider);
    final hint = WorkflowHintResolver.resolve(
      pageKey: 'stock_receipt.create',
      businessType: auth.businessType,
      industryCode: auth.industryCode,
    );

    return KKeyboardFormWrapper(
      onSubmit: _submit,
      onCancel: () => context.go(Routes.stockReceipts),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New Goods Receipt'),
          leading: IconButton(
            tooltip: 'Back to goods receipts',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(Routes.stockReceipts),
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
                    if (hint != null) ...[
                      KContextHint(hint: hint),
                      KSpacing.vGapMd,
                    ],

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

                    // ── Receipt Details ──
                    Text('Receipt Details', style: KTypography.titleLarge),
                    KSpacing.vGapSm,
                    KCompactRow(
                      children: [
                        KDatePicker(
                          label: 'Receipt Date',
                          value: _receiptDate,
                          onChanged: (d) => setState(() => _receiptDate = d),
                        ),
                        KTextField(
                          label: 'Supplier Invoice No',
                          controller: _supplierInvoiceNoCtl,
                        ),
                        KDatePicker(
                          label: 'Supplier Invoice Date',
                          value: _supplierInvoiceDate ?? _receiptDate,
                          onChanged: (d) =>
                              setState(() => _supplierInvoiceDate = d),
                        ),
                      ],
                    ),
                    KSpacing.vGapMd,

                    // ── Items Received ──
                    Row(
                      children: [
                        Text('Items Received', style: KTypography.titleLarge),
                        const Spacer(),
                        KButton.outlined(
                          label: 'Add Line Item',
                          icon: Icons.add,
                          size: KButtonSize.small,
                          onPressed: () => setState(() => _lines.add(_GrnLine())),
                        ),
                      ],
                    ),
                    KSpacing.vGapSm,
                    ...List.generate(_lines.length, (i) {
                      return _GrnLineCard(
                        line: _lines[i],
                        index: i,
                        onRemove: _lines.length > 1
                            ? () => setState(() => _lines.removeAt(i))
                            : null,
                        onChanged: () => setState(() {}),
                      );
                    }),
                    KSpacing.vGapLg,

                    // ── Landed Costs ──
                    _buildLandedCharges(),
                    KSpacing.vGapLg,

                    // ── Summary Card ──
                    KCard(
                      title: 'Receipt Summary',
                      child: Column(
                        children: [
                          _DetailSummaryRow(label: 'Taxable Amount', amount: _subtotal),
                          _DetailSummaryRow(label: 'GST Tax', amount: _totalTax),
                          if (_landedTotal > 0)
                            _DetailSummaryRow(label: 'Landed Charges', amount: _landedTotal),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Grand Total', style: KTypography.labelLarge.copyWith(fontWeight: FontWeight.w700)),
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
                        ],
                      ),
                    ),
                    KSpacing.vGapMd,

                    // ── Notes ──
                    KTextField(
                      label: 'Notes / Receiving Remarks (optional)',
                      controller: _notesCtl,
                      maxLines: 3,
                    ),
                    KSpacing.vGapLg,
                  ],
                ),
              ),
            ),

            // ── Sticky Bottom Action Bar ──
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
                        Text('Receipt Total', style: KTypography.caption),
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
                      onPressed: () => context.go(Routes.stockReceipts),
                    ),
                    KSpacing.hGapSm,
                    KButton.primary(
                      label: 'Save Draft',
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

  Widget _buildLandedCharges() {
    return KCard(
      title: 'Landed Costs (optional)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Freight, duty, insurance and other charges will be absorbed into item unit costs.',
            style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
          ),
          KSpacing.vGapSm,
          KCompactRow(
            children: [
              KTextField.amount(
                label: 'Freight',
                controller: _freightCtl,
                onChanged: (_) => setState(() {}),
              ),
              KTextField.amount(
                label: 'Duty',
                controller: _dutyCtl,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          KSpacing.vGapSm,
          KCompactRow(
            children: [
              KTextField.amount(
                label: 'Insurance',
                controller: _insuranceCtl,
                onChanged: (_) => setState(() {}),
              ),
              KTextField.amount(
                label: 'Other Charges',
                controller: _otherChargesCtl,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Models ──

class _GrnLine {
  String? itemId;
  String description = '';
  double quantity = 1;
  double unitPrice = 0;
  double gstRate = 0;
  String? taxGroupId;
  String batchNumber = '';
  DateTime? expiryDate;
  bool trackBatches = false;
  String uom = 'units';

  double get taxableAmount => quantity * unitPrice;
  double get taxAmount => taxableAmount * (gstRate / 100);
  double get lineTotal => taxableAmount + taxAmount;
}

class _GrnLineCard extends StatefulWidget {
  final _GrnLine line;
  final int index;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _GrnLineCard({
    required this.line,
    required this.index,
    this.onRemove,
    required this.onChanged,
  });

  @override
  State<_GrnLineCard> createState() => _GrnLineCardState();
}

class _GrnLineCardState extends State<_GrnLineCard> {
  late final TextEditingController _qtyCtl;
  late final TextEditingController _priceCtl;
  late final TextEditingController _batchCtl;

  @override
  void initState() {
    super.initState();
    _qtyCtl = TextEditingController(text: widget.line.quantity.toString());
    _priceCtl = TextEditingController(text: widget.line.unitPrice.toString());
    _batchCtl = TextEditingController(text: widget.line.batchNumber);
  }

  @override
  void dispose() {
    _qtyCtl.dispose();
    _priceCtl.dispose();
    _batchCtl.dispose();
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
      widget.line.trackBatches = picked['trackBatches'] == true;
      widget.line.uom = picked['uom']?.toString() ?? 'units';
      _priceCtl.text = widget.line.unitPrice.toString();
      widget.line.taxGroupId = picked['defaultTaxGroupId']?.toString();
      if (picked['defaultTaxRate'] != null) {
        widget.line.gstRate =
            (picked['defaultTaxRate'] as num).toDouble();
      }
    });
    widget.onChanged();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.line.expiryDate ?? now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => widget.line.expiryDate = picked);
      widget.onChanged();
    }
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
            Text(
              widget.line.description,
              style: KTypography.labelLarge.copyWith(fontWeight: FontWeight.w600),
            ),
            KSpacing.vGapSm,
            KCompactRow(
              children: [
                KTextField(
                  label: 'Quantity (${widget.line.uom})',
                  controller: _qtyCtl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    widget.line.quantity = double.tryParse(v) ?? 0;
                    widget.onChanged();
                  },
                ),
                KTextField.amount(
                  label: 'Unit Cost',
                  controller: _priceCtl,
                  onChanged: (v) {
                    widget.line.unitPrice = double.tryParse(v) ?? 0;
                    widget.onChanged();
                  },
                ),
              ],
            ),
            KSpacing.vGapSm,
            TaxGroupPicker(
              value: widget.line.taxGroupId,
              label: 'Tax (GST)',
              onChanged: (group) {
                setState(() {
                  widget.line.taxGroupId = group?.id;
                  widget.line.gstRate = group?.totalRate ?? 0;
                });
                widget.onChanged();
              },
            ),
            KSpacing.vGapSm,
            KCompactRow(
              children: [
                KTextField(
                  label: widget.line.trackBatches
                      ? 'Batch No (required)'
                      : 'Batch No (optional)',
                  controller: _batchCtl,
                  onChanged: (v) {
                    widget.line.batchNumber = v;
                    widget.onChanged();
                  },
                ),
                InkWell(
                  onTap: _pickExpiry,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Expiry Date'),
                    child: Text(
                      widget.line.expiryDate == null
                          ? 'Tap to set'
                          : DateFormatter.display(widget.line.expiryDate!),
                      style: KTypography.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
            KSpacing.vGapSm,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Line Total: ', style: KTypography.bodySmall),
                KMoney(
                  widget.line.lineTotal,
                  size: KMoneySize.small,
                  style: const TextStyle(
                    color: KColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ] else ...[
            KSpacing.vGapXs,
            Text('Pick an item to fill in cost, GST and unit',
                style: KTypography.bodySmall.copyWith(color: KColors.textHint)),
          ],
        ],
      ),
    );
  }
}

class _DetailSummaryRow extends StatelessWidget {
  final String label;
  final double amount;

  const _DetailSummaryRow({
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
          KMoney(amount, size: KMoneySize.small),
        ],
      ),
    );
  }
}
