import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import '../../contacts/data/contact_repository.dart';
import '../../tax_groups/data/tax_group_repository.dart';
import '../../tax_groups/presentation/widgets/tax_group_picker.dart';
import '../data/estimate_repository.dart';

/// Local draft model for a single line item on the create form.
class _LineDraft {
  final TextEditingController descriptionCtrl;
  final TextEditingController quantityCtrl;
  final TextEditingController rateCtrl;
  double discountPct;
  double taxRate;
  String? taxGroupId;

  _LineDraft({
    String? description,
    double quantity = 1,
    double rate = 0,
    this.discountPct = 0,
    this.taxRate = 0,
  })  : descriptionCtrl = TextEditingController(text: description ?? ''),
        quantityCtrl =
            TextEditingController(text: quantity.toString()),
        rateCtrl = TextEditingController(text: rate.toString());

  double get quantity => double.tryParse(quantityCtrl.text) ?? 0;
  double get rate => double.tryParse(rateCtrl.text) ?? 0;

  double get gross => quantity * rate;
  double get discountAmount => gross * (discountPct / 100);
  double get taxable => gross - discountAmount;
  double get taxAmount => taxable * (taxRate / 100);
  double get total => taxable + taxAmount;

  void dispose() {
    descriptionCtrl.dispose();
    quantityCtrl.dispose();
    rateCtrl.dispose();
  }
}

class EstimateCreateScreen extends ConsumerStatefulWidget {
  const EstimateCreateScreen({super.key});

  @override
  ConsumerState<EstimateCreateScreen> createState() =>
      _EstimateCreateScreenState();
}

class _EstimateCreateScreenState extends ConsumerState<EstimateCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _termsCtrl = TextEditingController();

  DateTime _estimateDate = DateTime.now();
  DateTime? _expiryDate;
  String? _contactId;
  String? _contactName;
  bool _submitting = false;

  final List<_LineDraft> _lines = [_LineDraft()];

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    _termsCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double get _subtotal => _lines.fold(0.0, (s, l) => s + l.taxable);
  double get _totalTax => _lines.fold(0.0, (s, l) => s + l.taxAmount);
  double get _grandTotal => _subtotal + _totalTax;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Estimate')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: KSpacing.pagePadding,
          children: [
            // Customer picker
            InkWell(
              onTap: _pickContact,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Customer *',
                  suffixIcon: _contactId != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() {
                            _contactId = null;
                            _contactName = null;
                          }),
                        )
                      : const Icon(Icons.person_search_outlined),
                ),
                child: Text(
                  _contactName ?? 'Select customer',
                  style: KTypography.bodyMedium,
                ),
              ),
            ),
            KSpacing.vGapMd,

            // Subject
            KTextField(
              label: 'Subject',
              controller: _subjectCtrl,
              hint: 'e.g. Q3 website redesign',
            ),
            KSpacing.vGapMd,

            // Reference number
            KTextField(
              label: 'Reference #',
              controller: _referenceCtrl,
              hint: 'Customer PO, RFQ, …',
            ),
            KSpacing.vGapMd,

            // Dates
            Row(
              children: [
                Expanded(
                  child: KDatePicker(
                    label: 'Estimate date *',
                    value: _estimateDate,
                    onChanged: (d) => setState(() => _estimateDate = d),
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: KDatePicker(
                    label: 'Expires on',
                    value: _expiryDate,
                    firstDate: DateTime.now(),
                    onChanged: (d) => setState(() => _expiryDate = d),
                  ),
                ),
              ],
            ),
            KSpacing.vGapLg,

            // Lines section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Line items', style: KTypography.h3),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _lines.add(_LineDraft())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add line'),
                ),
              ],
            ),
            KSpacing.vGapSm,
            for (int i = 0; i < _lines.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.md),
                child: _LineCard(
                  index: i,
                  line: _lines[i],
                  canRemove: _lines.length > 1,
                  onRemove: () => setState(() {
                    _lines[i].dispose();
                    _lines.removeAt(i);
                  }),
                  onChanged: () => setState(() {}),
                ),
              ),

            // Totals
            KCard(
              child: Column(
                children: [
                  _totalRow('Subtotal', _subtotal),
                  KSpacing.vGapXs,
                  _totalRow('Tax', _totalTax),
                  const Divider(),
                  _totalRow('Total', _grandTotal, bold: true),
                ],
              ),
            ),
            KSpacing.vGapMd,

            // Notes
            KTextField(
              label: 'Notes',
              controller: _notesCtrl,
              maxLines: 3,
              hint: 'Internal notes or message to customer',
            ),
            KSpacing.vGapMd,

            // Terms
            KTextField(
              label: 'Terms & conditions',
              controller: _termsCtrl,
              maxLines: 3,
            ),
            KSpacing.vGapLg,

            KButton(
              label: 'Save as Draft',
              fullWidth: true,
              isLoading: _submitting,
              onPressed: _submit,
            ),
            KSpacing.vGapMd,
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: bold ? KTypography.labelLarge : KTypography.bodyMedium),
        Text('₹${value.toStringAsFixed(2)}',
            style: bold ? KTypography.labelLarge : KTypography.bodyMedium),
      ],
    );
  }

  Future<void> _pickContact() async {
    final repo = ref.read(contactRepositoryProvider);
    Map<String, dynamic>? result;
    try {
      result = await repo.listContacts(type: 'CUSTOMER');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load customers')));
      return;
    }

    if (!mounted) return;
    final content = result['data'];
    final contacts = content is List
        ? content
        : (content is Map ? (content['content'] as List?) ?? [] : []);

    final filtered = contacts.where((c) {
      final t = (c as Map)['contactType'] as String? ?? '';
      return t == 'CUSTOMER' || t == 'BOTH';
    }).toList();

    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final c = filtered[i] as Map<String, dynamic>;
            return ListTile(
              leading: const CircleAvatar(
                  child: Icon(Icons.person_outline, size: 18)),
              title: Text(c['displayName'] as String? ?? 'Customer'),
              subtitle: Text(c['email'] as String? ?? ''),
              onTap: () => Navigator.pop(ctx, c),
            );
          },
        ),
      ),
    );

    if (picked != null) {
      setState(() {
        _contactId = picked['id']?.toString();
        _contactName = picked['displayName'] as String?;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_contactId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a customer')),
      );
      return;
    }
    final validLines = _lines
        .where((l) => l.descriptionCtrl.text.trim().isNotEmpty && l.quantity > 0)
        .toList();
    if (validLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one line item')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final payload = {
        'contactId': _contactId,
        'estimateDate': _formatDate(_estimateDate),
        if (_expiryDate != null) 'expiryDate': _formatDate(_expiryDate!),
        'subject': _subjectCtrl.text.trim(),
        'referenceNumber': _referenceCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
        'terms': _termsCtrl.text.trim(),
        'currency': 'INR',
        'lines': validLines
            .map((l) => {
                  'description': l.descriptionCtrl.text.trim(),
                  'quantity': l.quantity,
                  'rate': l.rate,
                  'discountPct': l.discountPct,
                  'taxRate': l.taxRate,
                  if (l.taxGroupId != null) 'taxGroupId': l.taxGroupId,
                })
            .toList(),
      };

      await ref.read(estimateRepositoryProvider).createEstimate(payload);
      if (!mounted) return;

      ref.invalidate(estimateListProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estimate saved as draft')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is DioException
            ? ApiErrorParser.message(e)
            : 'Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _LineCard extends StatelessWidget {
  final int index;
  final _LineDraft line;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _LineCard({
    required this.index,
    required this.line,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Line ${index + 1}', style: KTypography.labelLarge),
              const Spacer(),
              if (canRemove)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: KColors.error, size: 20),
                  onPressed: onRemove,
                  tooltip: 'Remove line',
                ),
            ],
          ),
          KSpacing.vGapSm,
          KTextField(
            label: 'Description *',
            controller: line.descriptionCtrl,
            onChanged: (_) => onChanged(),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          KSpacing.vGapSm,
          Row(
            children: [
              Expanded(
                child: KTextField(
                  label: 'Quantity',
                  controller: line.quantityCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => onChanged(),
                ),
              ),
              KSpacing.hGapSm,
              Expanded(
                child: KTextField.amount(
                  label: 'Rate',
                  controller: line.rateCtrl,
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
          KSpacing.vGapSm,
          Row(
            children: [
              Expanded(
                child: TaxGroupPicker(
                  value: line.taxGroupId,
                  label: 'Tax',
                  onChanged: (group) {
                    line.taxGroupId = group?.id;
                    line.taxRate = group?.totalRate ?? 0;
                    onChanged();
                  },
                ),
              ),
              KSpacing.hGapSm,
              Expanded(
                child: KTextField(
                  label: 'Discount %',
                  initialValue: line.discountPct.toString(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    line.discountPct = double.tryParse(v) ?? 0;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          KSpacing.vGapSm,
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Line total: ₹${line.total.toStringAsFixed(2)}',
              style: KTypography.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}
