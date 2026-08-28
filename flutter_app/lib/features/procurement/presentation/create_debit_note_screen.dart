import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/debit_note_repository.dart';
import 'supplier_picker_sheet.dart';

// ── Return reason constants ──

const _returnReasons = [
  _ReturnReason('EXPIRED', 'Expired Medicines'),
  _ReturnReason('DAMAGED', 'Damaged'),
  _ReturnReason('WRONG_ITEM', 'Wrong Item Received'),
  _ReturnReason('QUALITY_ISSUE', 'Quality Issue'),
  _ReturnReason('EXCESS_STOCK', 'Excess Stock'),
];

class _ReturnReason {
  final String value;
  final String label;
  const _ReturnReason(this.value, this.label);
}

// ── Line item model ──

class _DnLine {
  final TextEditingController itemNameCtl;
  final TextEditingController batchNumberCtl;
  final TextEditingController qtyCtl;
  final TextEditingController unitPriceCtl;
  final TextEditingController taxRateCtl;
  DateTime? expiryDate;

  _DnLine({DateTime? prefillExpiry})
      : itemNameCtl = TextEditingController(),
        batchNumberCtl = TextEditingController(),
        qtyCtl = TextEditingController(text: '1'),
        unitPriceCtl = TextEditingController(text: '0'),
        taxRateCtl = TextEditingController(text: '12'),
        expiryDate = prefillExpiry;

  void dispose() {
    itemNameCtl.dispose();
    batchNumberCtl.dispose();
    qtyCtl.dispose();
    unitPriceCtl.dispose();
    taxRateCtl.dispose();
  }

  double get qty => double.tryParse(qtyCtl.text) ?? 0;
  double get unitPrice => double.tryParse(unitPriceCtl.text) ?? 0;
  double get taxRate => double.tryParse(taxRateCtl.text) ?? 0;
  double get subtotal => qty * unitPrice;
  double get taxAmount => subtotal * taxRate / 100;
  double get lineTotal => subtotal + taxAmount;
}

// ── Screen ──

class CreateDebitNoteScreen extends ConsumerStatefulWidget {
  /// Optional pre-filled expiry date (when launched from near-expiry screen).
  final DateTime? prefillExpiryDate;
  final Map<String, dynamic>? prefill;

  const CreateDebitNoteScreen({
    super.key,
    this.prefillExpiryDate,
    this.prefill,
  });

  @override
  ConsumerState<CreateDebitNoteScreen> createState() =>
      _CreateDebitNoteScreenState();
}

class _CreateDebitNoteScreenState
    extends ConsumerState<CreateDebitNoteScreen> {
  bool _isSaving = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  Map<String, dynamic>? _supplier;
  String? _returnReason;
  DateTime _noteDate = DateTime.now();
  final _refBillCtl = TextEditingController();
  final _notesCtl = TextEditingController();

  late List<_DnLine> _lines;

  @override
  void initState() {
    super.initState();
    _lines = [_DnLine(prefillExpiry: widget.prefillExpiryDate)];
    _applyPrefill();
  }

  void _applyPrefill() {
    final prefill = widget.prefill;
    if (prefill == null) return;

    final reason = prefill['returnReason']?.toString();
    if (reason != null && reason.isNotEmpty) {
      _returnReason = reason;
    }

    final notes = prefill['notes']?.toString();
    if (notes != null && notes.isNotEmpty) {
      _notesCtl.text = notes;
    }

    final rawLines = prefill['lines'];
    if (rawLines is List && rawLines.isNotEmpty) {
      for (final line in _lines) {
        line.dispose();
      }
      _lines = rawLines.map((raw) {
        final line = _DnLine();
        if (raw is Map) {
          final map = Map<String, dynamic>.from(raw);
          line.itemNameCtl.text = map['itemName']?.toString() ??
              map['description']?.toString() ??
              '';
          line.batchNumberCtl.text = map['batchNumber']?.toString() ?? '';
          final qty = map['quantity'];
          if (qty != null) {
            line.qtyCtl.text = qty.toString();
          }
          final expiry = map['expiryDate']?.toString();
          if (expiry != null && expiry.isNotEmpty) {
            line.expiryDate = DateTime.tryParse(expiry);
          }
        }
        return line;
      }).toList();
    }
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    _refBillCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  double get _subtotal =>
      _lines.fold(0.0, (sum, l) => sum + l.subtotal);

  double get _totalTax =>
      _lines.fold(0.0, (sum, l) => sum + l.taxAmount);

  double get _grandTotal => _subtotal + _totalTax;

  Future<void> _pickSupplier() async {
    final picked = await showSupplierPicker(context);
    if (picked != null) setState(() => _supplier = picked);
  }

  bool _validate() {
    if (_supplier == null) {
      setState(() => _errorMessage = 'Please select a supplier');
      return false;
    }
    if (_returnReason == null) {
      setState(() => _errorMessage = 'Please select a return reason');
      return false;
    }
    final hasItems =
        _lines.any((l) => l.itemNameCtl.text.trim().isNotEmpty);
    if (!hasItems) {
      setState(() => _errorMessage = 'Add at least one line item with a name');
      return false;
    }
    return true;
  }

  Map<String, dynamic> _buildBody() {
    return {
      'supplierId': _supplier!['id'],
      'supplierName': _supplier!['name'],
      'noteDate': DateFormatter.api(_noteDate),
      'returnReason': _returnReason,
      if (_refBillCtl.text.trim().isNotEmpty)
        'referenceBillId': _refBillCtl.text.trim(),
      if (_notesCtl.text.trim().isNotEmpty) 'notes': _notesCtl.text.trim(),
      'lines': _lines
          .where((l) => l.itemNameCtl.text.trim().isNotEmpty)
          .map((l) => {
                'description': l.itemNameCtl.text.trim(),
                if (l.batchNumberCtl.text.trim().isNotEmpty)
                  'batchNumber': l.batchNumberCtl.text.trim(),
                if (l.expiryDate != null)
                  'expiryDate': DateFormatter.api(l.expiryDate!),
                'quantity': l.qty,
                'unitPrice': l.unitPrice,
                'taxRate': l.taxRate,
              })
          .toList(),
    };
  }

  Future<void> _saveAsDraft() async {
    if (!_validate()) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final repo = ref.read(debitNoteRepositoryProvider);
      final created = await repo.create(_buildBody());
      ref.invalidate(debitNotesProvider);
      final id = created['id']?.toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debit note saved as draft')),
        );
        if (id != null) {
          context.go('/debit-notes/$id');
        } else {
          context.go(Routes.debitNotes);
        }
      }
    } catch (e, st) {
      debugPrint('[CreateDN] saveAsDraft FAILED: $e\n$st');
      setState(() => _errorMessage = _extractError(e, 'Failed to save debit note'));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveAndSubmit() async {
    if (!_validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final repo = ref.read(debitNoteRepositoryProvider);
      final created = await repo.create(_buildBody());
      final id = created['id']?.toString();
      if (id != null) {
        await repo.submit(id);
      }
      ref.invalidate(debitNotesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debit note submitted')),
        );
        if (id != null) {
          context.go('/debit-notes/$id');
        } else {
          context.go(Routes.debitNotes);
        }
      }
    } catch (e, st) {
      debugPrint('[CreateDN] saveAndSubmit FAILED: $e\n$st');
      setState(
          () => _errorMessage = _extractError(e, 'Failed to submit debit note'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _extractError(Object e, String fallback) {
    if (e is DioException) {
      final body = e.response?.data;
      if (body is Map) {
        return body['message'] as String? ??
            body['error'] as String? ??
            fallback;
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isSaving || _isSubmitting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Debit Note'),
        leading: IconButton(
          tooltip: 'Back to debit notes',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.debitNotes),
        ),
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  KSpacing.md, KSpacing.md, KSpacing.md, 0),
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
                            color:
                                KColors.primaryLight.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.local_shipping_outlined,
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
                                Text(
                                  'GSTIN: ${_supplier!['gstin']}',
                                  style: KTypography.mono(fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: KColors.textHint),
                      ],
                    ),
                  ),
                  KSpacing.vGapMd,

                  // ── Return Reason & Date ──
                  Text('Return Details', style: KTypography.labelLarge),
                  KSpacing.vGapSm,
                  _ReturnReasonDropdown(
                    value: _returnReason,
                    onChanged: (v) => setState(() => _returnReason = v),
                  ),
                  KSpacing.vGapSm,
                  KDatePicker(
                    label: 'Note Date',
                    value: _noteDate,
                    onChanged: (d) => setState(() => _noteDate = d),
                  ),
                  KSpacing.vGapSm,
                  KTextField(
                    label: 'Reference Bill No. (optional)',
                    controller: _refBillCtl,
                    hint: 'e.g. BILL-2024-001',
                  ),
                  KSpacing.vGapSm,
                  KTextField(
                    label: 'Notes (optional)',
                    controller: _notesCtl,
                    maxLines: 3,
                  ),
                  KSpacing.vGapLg,

                  // ── Line Items ──
                  Text('Return Items', style: KTypography.h2),
                  KSpacing.vGapMd,
                  ...List.generate(_lines.length, (i) {
                    return _DnLineCard(
                      line: _lines[i],
                      index: i,
                      onRemove: _lines.length > 1
                          ? () => setState(() {
                                _lines[i].dispose();
                                _lines.removeAt(i);
                              })
                          : null,
                      onChanged: () => setState(() {}),
                    );
                  }),
                  KSpacing.vGapMd,
                  KButton.outlined(
                    label: 'Add Line Item',
                    icon: Icons.add,
                    onPressed: () => setState(() => _lines.add(_DnLine())),
                  ),
                  KSpacing.vGapLg,

                  // ── Totals ──
                  KCard(
                    child: Column(
                      children: [
                        _DetailSummaryRow(
                          label: 'Subtotal',
                          amount: _subtotal,
                        ),
                        _DetailSummaryRow(
                          label: 'Tax',
                          amount: _totalTax,
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total', style: KTypography.labelLarge.copyWith(fontWeight: FontWeight.w700)),
                            KMoney(
                              _grandTotal,
                              size: KMoneySize.medium,
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
                  KSpacing.vGapLg,
                ],
              ),
            ),
          ),

          // ── Bottom action bar ──
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
                      Text('Total', style: KTypography.caption),
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
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: KButton.outlined(
                      label: 'Save Draft',
                      icon: Icons.save_outlined,
                      onPressed: isBusy ? null : _saveAsDraft,
                      isLoading: _isSaving,
                    ),
                  ),
                  KButton.primary(
                    label: 'Submit',
                    icon: Icons.send_outlined,
                    onPressed: isBusy ? null : _saveAndSubmit,
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
}

// ── Return Reason Dropdown ──

class _ReturnReasonDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _ReturnReasonDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: 'Return Reason *',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KSpacing.radiusMd),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KSpacing.radiusMd),
          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: KSpacing.md,
          vertical: 14,
        ),
      ),
      hint: const Text('Select reason'),
      items: _returnReasons
          .map((r) => DropdownMenuItem(
                value: r.value,
                child: Text(r.label),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

// ── Line item card ──

class _DnLineCard extends StatefulWidget {
  final _DnLine line;
  final int index;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _DnLineCard({
    required this.line,
    required this.index,
    this.onRemove,
    required this.onChanged,
  });

  @override
  State<_DnLineCard> createState() => _DnLineCardState();
}

class _DnLineCardState extends State<_DnLineCard> {
  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.line.expiryDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => widget.line.expiryDate = picked);
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Item ${widget.index + 1}',
                  style: KTypography.labelLarge),
              const Spacer(),
              if (widget.onRemove != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: KColors.error, size: 20),
                  tooltip: 'Remove line',
                  onPressed: widget.onRemove,
                ),
            ],
          ),
          KSpacing.vGapSm,
          KTextField(
            label: 'Item Name *',
            controller: line.itemNameCtl,
            onChanged: (_) => widget.onChanged(),
          ),
          KSpacing.vGapSm,
          KCompactRow(
            children: [
              Expanded(
                flex: 5,
                child: KTextField(
                  label: 'Batch Number',
                  hint: 'Optional',
                  controller: line.batchNumberCtl,
                  onChanged: (_) => widget.onChanged(),
                ),
              ),
              Expanded(
                flex: 5,
                child: InkWell(
                  onTap: _pickExpiryDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Expiry Date',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(KSpacing.radiusMd),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: KSpacing.md,
                        vertical: 14,
                      ),
                      suffixIcon: const Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(
                      line.expiryDate != null
                          ? DateFormatter.display(line.expiryDate!)
                          : 'Optional',
                      style: line.expiryDate != null
                          ? KTypography.bodyMedium
                          : KTypography.bodyMedium
                              .copyWith(color: KColors.textHint),
                    ),
                  ),
                ),
              ),
            ],
          ),
          KSpacing.vGapSm,
          KCompactRow(
            children: [
              Expanded(
                flex: 3,
                child: KTextField(
                  label: 'Quantity',
                  controller: line.qtyCtl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => widget.onChanged(),
                ),
              ),
              Expanded(
                flex: 4,
                child: KTextField.amount(
                  label: 'Unit Price',
                  controller: line.unitPriceCtl,
                  onChanged: (_) => widget.onChanged(),
                ),
              ),
              Expanded(
                flex: 3,
                child: KTextField(
                  label: 'Tax Rate %',
                  controller: line.taxRateCtl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => widget.onChanged(),
                ),
              ),
            ],
          ),
          KSpacing.vGapSm,
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Line Total: ', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
              KMoney(
                line.lineTotal,
                size: KMoneySize.small,
                style: const TextStyle(fontWeight: FontWeight.w700, color: KColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailSummaryRow extends StatelessWidget {
  final String label;
  final double amount;

  const _DetailSummaryRow({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: KTypography.bodyMedium.copyWith(color: KColors.textSecondary)),
          KMoney(amount, size: KMoneySize.small),
        ],
      ),
    );
  }
}
