import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../customers/data/customer_repository.dart';
import '../data/credit_note_repository.dart';
import '../data/credit_note_providers.dart';

/// GST rate options for India.
const _gstRates = [0.0, 5.0, 12.0, 18.0, 28.0];

/// Common revenue account codes.
const _accountCodes = [
  ('4000', 'Sales Revenue'),
  ('4010', 'Service Revenue'),
  ('4020', 'Other Income'),
];

class CreditNoteCreateScreen extends ConsumerStatefulWidget {
  const CreditNoteCreateScreen({super.key});

  @override
  ConsumerState<CreditNoteCreateScreen> createState() =>
      _CreditNoteCreateScreenState();
}

class _CreditNoteCreateScreenState
    extends ConsumerState<CreditNoteCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // Header fields
  String? _selectedCustomerId;
  String? _selectedCustomerName;
  DateTime _creditNoteDate = DateTime.now();
  final _reasonController = TextEditingController();
  final _placeOfSupplyController = TextEditingController();

  // Line items
  final List<_LineItem> _lines = [_LineItem()];

  @override
  void dispose() {
    _reasonController.dispose();
    _placeOfSupplyController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  double get _subtotal => _lines.fold(
      0.0, (sum, line) => sum + line.taxableAmount);

  double get _taxTotal => _lines.fold(
      0.0, (sum, line) => sum + line.taxAmount);

  double get _grandTotal => _subtotal + _taxTotal;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(creditNoteRepositoryProvider);
      final data = {
        'customerId': _selectedCustomerId,
        'creditNoteDate': DateFormatter.api(_creditNoteDate),
        'reason': _reasonController.text.trim(),
        if (_placeOfSupplyController.text.trim().isNotEmpty)
          'placeOfSupply': _placeOfSupplyController.text.trim(),
        'lines': _lines
            .map((line) => {
                  'description': line.descriptionController.text.trim(),
                  if (line.hsnController.text.trim().isNotEmpty)
                    'hsnCode': line.hsnController.text.trim(),
                  'quantity': double.tryParse(
                          line.qtyController.text) ??
                      1,
                  'unitPrice': double.tryParse(
                          line.priceController.text) ??
                      0,
                  'gstRate': line.gstRate,
                  'accountCode': line.accountCode,
                })
            .toList(),
      };

      await repo.createCreditNote(data);
      ref.invalidate(creditNoteListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credit note created')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create credit note: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _addLine() {
    setState(() => _lines.add(_LineItem()));
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _creditNoteDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _creditNoteDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Credit Note'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: KSpacing.pagePadding,
          children: [
            // ── Customer Selection ──
            _buildCustomerPicker(),
            KSpacing.vGapMd,

            // ── Date ──
            KTextField(
              label: 'Credit Note Date',
              controller: TextEditingController(
                text: DateFormatter.display(_creditNoteDate),
              ),
              readOnly: true,
              prefixIcon: Icons.calendar_today,
              onTap: _pickDate,
            ),
            KSpacing.vGapMd,

            // ── Reason ──
            KTextField(
              label: 'Reason',
              hint: 'e.g., Goods returned, Pricing error',
              controller: _reasonController,
              maxLines: 2,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Reason is required' : null,
            ),
            KSpacing.vGapMd,

            // ── Place of Supply ──
            KTextField(
              label: 'Place of Supply (State Code)',
              hint: 'e.g., 29 for Karnataka',
              controller: _placeOfSupplyController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
            ),
            KSpacing.vGapLg,

            // ── Line Items ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Line Items', style: KTypography.h3),
                TextButton.icon(
                  onPressed: _addLine,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Item'),
                ),
              ],
            ),
            KSpacing.vGapSm,

            ...List.generate(_lines.length, (i) => _buildLineCard(i)),

            KSpacing.vGapLg,

            // ── Totals ──
            KCard(
              child: Column(
                children: [
                  _TotalRow(
                    label: 'Subtotal',
                    value: CurrencyFormatter.formatIndian(_subtotal),
                  ),
                  _TotalRow(
                    label: 'Tax (GST)',
                    value: CurrencyFormatter.formatIndian(_taxTotal),
                  ),
                  const Divider(),
                  _TotalRow(
                    label: 'Total',
                    value: CurrencyFormatter.formatIndian(_grandTotal),
                    style: KTypography.amountMedium.copyWith(
                      color: KColors.error,
                    ),
                  ),
                ],
              ),
            ),
            KSpacing.vGapLg,

            // ── Submit ──
            KButton(
              label: 'Create Credit Note',
              icon: Icons.check,
              fullWidth: true,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submit,
            ),
            KSpacing.vGapXl,
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerPicker() {
    final customersAsync = ref.watch(customerListProvider);

    return customersAsync.when(
      loading: () => const KTextField(
        label: 'Customer',
        readOnly: true,
        hint: 'Loading customers...',
      ),
      error: (_, __) => const KTextField(
        label: 'Customer',
        readOnly: true,
        hint: 'Failed to load customers',
      ),
      data: (data) {
        final content = data['data'];
        final customers = (content is List)
            ? content
            : (content is Map ? (content['content'] as List?) ?? [] : []);

        return DropdownButtonFormField<String>(
          value: _selectedCustomerId,
          decoration: const InputDecoration(
            labelText: 'Customer',
            prefixIcon: Icon(Icons.person_outline),
          ),
          items: customers.map<DropdownMenuItem<String>>((c) {
            final cMap = c as Map<String, dynamic>;
            return DropdownMenuItem(
              value: cMap['id']?.toString(),
              child: Text(cMap['name'] as String? ?? 'Unknown'),
            );
          }).toList(),
          onChanged: (v) {
            setState(() {
              _selectedCustomerId = v;
              final customer = customers.firstWhere(
                (c) => (c as Map)['id']?.toString() == v,
                orElse: () => <String, dynamic>{},
              ) as Map<String, dynamic>;
              _selectedCustomerName = customer['name'] as String?;
            });
          },
          validator: (v) => v == null ? 'Select a customer' : null,
        );
      },
    );
  }

  Widget _buildLineCard(int index) {
    final line = _lines[index];

    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      borderColor: KColors.divider,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with line number and remove button
          Row(
            children: [
              Text('Item ${index + 1}', style: KTypography.labelLarge),
              const Spacer(),
              if (_lines.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: KColors.error),
                  onPressed: () => _removeLine(index),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          KSpacing.vGapSm,

          // Description
          KTextField(
            label: 'Description',
            controller: line.descriptionController,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Description required'
                : null,
          ),
          KSpacing.vGapSm,

          // HSN Code
          KTextField(
            label: 'HSN/SAC Code',
            hint: 'Optional',
            controller: line.hsnController,
            keyboardType: TextInputType.number,
          ),
          KSpacing.vGapSm,

          // Quantity + Unit Price
          Row(
            children: [
              Expanded(
                child: KTextField(
                  label: 'Qty',
                  controller: line.qtyController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final val = double.tryParse(v ?? '');
                    if (val == null || val <= 0) return 'Invalid';
                    return null;
                  },
                ),
              ),
              KSpacing.hGapMd,
              Expanded(
                flex: 2,
                child: KTextField.amount(
                  label: 'Unit Price',
                  controller: line.priceController,
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final val = double.tryParse(v ?? '');
                    if (val == null || val < 0) return 'Invalid';
                    return null;
                  },
                ),
              ),
            ],
          ),
          KSpacing.vGapSm,

          // GST Rate + Account Code
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<double>(
                  value: line.gstRate,
                  decoration: const InputDecoration(labelText: 'GST Rate'),
                  items: _gstRates
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text('${r.toStringAsFixed(0)}%'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() {
                    line.gstRate = v ?? 0;
                  }),
                ),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: line.accountCode,
                  decoration:
                      const InputDecoration(labelText: 'Account'),
                  items: _accountCodes
                      .map((a) => DropdownMenuItem(
                            value: a.$1,
                            child: Text(a.$2),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => line.accountCode = v ?? '4000'),
                ),
              ),
            ],
          ),
          KSpacing.vGapSm,

          // Line total
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Line Total: ${CurrencyFormatter.formatIndian(line.lineTotal)}',
              style: KTypography.labelMedium.copyWith(
                color: KColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mutable line item model for the create form.
class _LineItem {
  final descriptionController = TextEditingController();
  final hsnController = TextEditingController();
  final qtyController = TextEditingController(text: '1');
  final priceController = TextEditingController();
  double gstRate = 18.0;
  String accountCode = '4000';

  double get _qty => double.tryParse(qtyController.text) ?? 0;
  double get _price => double.tryParse(priceController.text) ?? 0;
  double get taxableAmount => _qty * _price;
  double get taxAmount => taxableAmount * gstRate / 100;
  double get lineTotal => taxableAmount + taxAmount;

  void dispose() {
    descriptionController.dispose();
    hsnController.dispose();
    qtyController.dispose();
    priceController.dispose();
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? style;

  const _TotalRow({
    required this.label,
    required this.value,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: KTypography.bodyMedium),
          Text(value, style: style ?? KTypography.amountSmall),
        ],
      ),
    );
  }
}
