import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../routing/app_router.dart';
import '../../inventory/presentation/item_picker_sheet.dart';
import '../../tax_groups/data/tax_group_repository.dart';
import '../../tax_groups/presentation/widgets/tax_group_picker.dart';
import '../data/stock_receipt_repository.dart';
import 'supplier_picker_sheet.dart';

/// Two-step GRN creation: pick supplier + add lines, then review.
/// Saving creates the receipt in DRAFT state — posting (which writes to
/// the inventory ledger) happens from the detail screen so the user has
/// one last chance to bail out.
class StockReceiptCreateScreen extends ConsumerStatefulWidget {
  const StockReceiptCreateScreen({super.key});

  @override
  ConsumerState<StockReceiptCreateScreen> createState() =>
      _StockReceiptCreateScreenState();
}

class _StockReceiptCreateScreenState
    extends ConsumerState<StockReceiptCreateScreen> {
  int _currentStep = 0;
  bool _isSubmitting = false;
  String? _errorMessage;

  Map<String, dynamic>? _supplier;
  DateTime _receiptDate = DateTime.now();
  DateTime? _supplierInvoiceDate;
  final _supplierInvoiceNoCtl = TextEditingController();
  final _notesCtl = TextEditingController();

  final List<_GrnLine> _lines = [_GrnLine()];

  @override
  void dispose() {
    _supplierInvoiceNoCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  double get _subtotal => _lines.fold(0, (sum, l) => sum + l.taxableAmount);
  double get _totalTax => _lines.fold(0, (sum, l) => sum + l.taxAmount);
  double get _grandTotal => _subtotal + _totalTax;

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
      setState(() =>
          _errorMessage = 'Add at least one line item with a picked item');
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
      setState(() => _errorMessage = 'Failed to create goods receipt');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Goods Receipt'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go(Routes.stockReceipts),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: KColors.surface,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StepTab(
                    label: 'Supplier',
                    index: 0,
                    current: _currentStep,
                    onTap: () => setState(() => _currentStep = 0)),
                _stepConnector(),
                _StepTab(
                    label: 'Items',
                    index: 1,
                    current: _currentStep,
                    onTap: () => setState(() => _currentStep = 1)),
                _stepConnector(),
                _StepTab(
                    label: 'Review',
                    index: 2,
                    current: _currentStep,
                    onTap: () => setState(() => _currentStep = 2)),
              ],
            ),
          ),
          const Divider(height: 1),
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
              child: switch (_currentStep) {
                0 => _buildSupplierStep(),
                1 => _buildItemsStep(),
                2 => _buildReviewStep(),
                _ => const SizedBox(),
              },
            ),
          ),
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
                  if (_currentStep > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: KButton(
                        label: 'Back',
                        variant: KButtonVariant.outlined,
                        onPressed: () => setState(() => _currentStep--),
                      ),
                    ),
                  if (_currentStep < 2)
                    KButton(
                      label: 'Next',
                      onPressed: () {
                        if (_currentStep == 0 && _supplier == null) {
                          setState(() =>
                              _errorMessage = 'Please select a supplier');
                          return;
                        }
                        setState(() => _currentStep++);
                      },
                    )
                  else
                    KButton(
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
    );
  }

  Widget _stepConnector() {
    return Container(
      width: 32,
      height: 2,
      color: KColors.divider,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  // ── Step 0: Supplier ──
  Widget _buildSupplierStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Supplier', style: KTypography.h2),
        KSpacing.vGapMd,
        KCard(
          onTap: _pickSupplier,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: KColors.primaryLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_shipping_outlined,
                    color: KColors.primary),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _supplier?['name']?.toString() ?? 'Tap to pick supplier',
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
        KSpacing.vGapLg,
        const Divider(),
        KSpacing.vGapMd,
        Text('Receipt Details', style: KTypography.labelLarge),
        KSpacing.vGapSm,
        KDatePicker(
          label: 'Receipt Date',
          value: _receiptDate,
          onChanged: (d) => setState(() => _receiptDate = d),
        ),
        KSpacing.vGapSm,
        KTextField(
          label: "Supplier Invoice No (optional)",
          controller: _supplierInvoiceNoCtl,
        ),
        KSpacing.vGapSm,
        KDatePicker(
          label: 'Supplier Invoice Date (optional)',
          value: _supplierInvoiceDate ?? _receiptDate,
          onChanged: (d) => setState(() => _supplierInvoiceDate = d),
        ),
      ],
    );
  }

  // ── Step 1: Line items ──
  Widget _buildItemsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Items Received', style: KTypography.h2),
        KSpacing.vGapMd,
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
        KSpacing.vGapMd,
        KButton(
          label: 'Add Line Item',
          icon: Icons.add,
          variant: KButtonVariant.outlined,
          onPressed: () => setState(() => _lines.add(_GrnLine())),
        ),
        KSpacing.vGapLg,
        KCard(
          child: Column(
            children: [
              _SummaryRow(
                  label: 'Taxable',
                  value: CurrencyFormatter.formatIndian(_subtotal)),
              _SummaryRow(
                  label: 'GST',
                  value: CurrencyFormatter.formatIndian(_totalTax)),
              const Divider(),
              _SummaryRow(
                label: 'Grand Total',
                value: CurrencyFormatter.formatIndian(_grandTotal),
                bold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 2: Review ──
  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review Receipt', style: KTypography.h2),
        KSpacing.vGapMd,
        KCard(
          title: 'Supplier',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _supplier?['name']?.toString() ?? '--',
                style: KTypography.bodyLarge,
              ),
              KSpacing.vGapSm,
              KDetailRow(
                label: 'Receipt Date',
                value: DateFormatter.display(_receiptDate),
              ),
              if (_supplierInvoiceNoCtl.text.trim().isNotEmpty)
                KDetailRow(
                    label: 'Supplier Invoice',
                    value: _supplierInvoiceNoCtl.text.trim()),
              if (_supplierInvoiceDate != null)
                KDetailRow(
                    label: 'Supplier Inv. Date',
                    value: DateFormatter.display(_supplierInvoiceDate!)),
            ],
          ),
        ),
        KSpacing.vGapMd,
        KCard(
          title: 'Items (${_lines.where((l) => l.itemId != null).length})',
          child: Column(
            children: _lines.where((l) => l.itemId != null).map((l) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.description.isEmpty
                                ? '(unnamed)'
                                : l.description,
                            style: KTypography.bodyMedium,
                          ),
                          Text(
                            '${l.quantity} ${l.uom} x ${CurrencyFormatter.formatIndian(l.unitPrice)}'
                            '${l.batchNumber.isNotEmpty ? ' • Batch: ${l.batchNumber}' : ''}',
                            style: KTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatIndian(l.lineTotal),
                      style: KTypography.amountSmall,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        KSpacing.vGapMd,
        KCard(
          child: Column(
            children: [
              _SummaryRow(
                  label: 'Taxable',
                  value: CurrencyFormatter.formatIndian(_subtotal)),
              _SummaryRow(
                  label: 'GST',
                  value: CurrencyFormatter.formatIndian(_totalTax)),
              const Divider(),
              _SummaryRow(
                label: 'Total',
                value: CurrencyFormatter.formatIndian(_grandTotal),
                bold: true,
              ),
            ],
          ),
        ),
        KSpacing.vGapMd,
        KTextField(
          label: 'Notes (optional)',
          controller: _notesCtl,
          maxLines: 3,
        ),
        KSpacing.vGapMd,
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: KColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: KColors.warning.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 18, color: KColors.warning),
              KSpacing.hGapSm,
              Expanded(
                child: Text(
                  'Saving creates a DRAFT receipt. Stock balances are updated only after you press "Receive" on the detail screen.',
                  style: KTypography.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Models ──

class _GrnLine {
  String? itemId;
  String description = '';
  String uom = 'PCS';
  double quantity = 1;
  double unitPrice = 0;
  double gstRate = 0;
  String? taxGroupId;
  String batchNumber = '';
  DateTime? expiryDate;

  double get taxableAmount => quantity * unitPrice;
  double get taxAmount => taxableAmount * gstRate / 100;
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
      widget.line.uom = picked['unitOfMeasure']?.toString() ?? 'PCS';
      // For GRNs the relevant unit cost is the supplier's purchase price.
      widget.line.unitPrice =
          (picked['purchasePrice'] as num?)?.toDouble() ?? 0;
      _priceCtl.text = widget.line.unitPrice.toString();
      final pickedGst = (picked['gstRate'] as num?)?.toDouble();
      if (pickedGst != null && [0, 5, 12, 18, 28].contains(pickedGst.toInt())) {
        widget.line.gstRate = pickedGst;
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
                    label: 'Quantity (${widget.line.uom})',
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
                    label: 'Unit Cost',
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
            Row(
              children: [
                Expanded(
                  child: KTextField(
                    label: 'Batch No (optional)',
                    controller: _batchCtl,
                    onChanged: (v) {
                      widget.line.batchNumber = v;
                      widget.onChanged();
                    },
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: InkWell(
                    onTap: _pickExpiry,
                    child: InputDecorator(
                      decoration:
                          const InputDecoration(labelText: 'Expiry'),
                      child: Text(
                        widget.line.expiryDate == null
                            ? 'Tap to set'
                            : DateFormatter.display(widget.line.expiryDate!),
                      ),
                    ),
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
            Text('Pick an item to fill in cost, GST and unit',
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

class _StepTab extends StatelessWidget {
  final String label;
  final int index;
  final int current;
  final VoidCallback onTap;
  const _StepTab({
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    final isCompleted = index < current;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isActive || isCompleted
                  ? KColors.primary
                  : KColors.divider,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        color:
                            isActive ? Colors.white : KColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
            ),
          ),
          KSpacing.hGapXs,
          Text(
            label,
            style: KTypography.labelMedium.copyWith(
              color: isActive ? KColors.primary : KColors.textSecondary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
