import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import '../data/prescription_repository.dart';

class AddPrescriptionScreen extends ConsumerStatefulWidget {
  final String contactId;
  final String? contactName;
  final String? receiptId;
  final String? prefillRxNumber;

  const AddPrescriptionScreen({
    super.key,
    required this.contactId,
    this.contactName,
    this.receiptId,
    this.prefillRxNumber,
  });

  @override
  ConsumerState<AddPrescriptionScreen> createState() =>
      _AddPrescriptionScreenState();
}

class _AddPrescriptionScreenState
    extends ConsumerState<AddPrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Controllers for top-level fields
  late final TextEditingController _rxNumberCtrl;
  final TextEditingController _doctorNameCtrl = TextEditingController();
  final TextEditingController _doctorRegCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  DateTime _prescribedDate = DateTime.now();
  DateTime? _validUntil;

  // Items list — each entry holds controllers for name, qty, dosage
  final List<_PrescriptionItemRow> _itemRows = [];

  @override
  void initState() {
    super.initState();
    _rxNumberCtrl =
        TextEditingController(text: widget.prefillRxNumber ?? '');
    // Default validUntil = 30 days from today
    _validUntil = DateTime.now().add(const Duration(days: 30));
    _itemRows.add(_PrescriptionItemRow());
  }

  @override
  void dispose() {
    _rxNumberCtrl.dispose();
    _doctorNameCtrl.dispose();
    _doctorRegCtrl.dispose();
    _notesCtrl.dispose();
    for (final row in _itemRows) {
      row.dispose();
    }
    super.dispose();
  }

  // ── Date helpers ────────────────────────────────────────────

  Future<void> _pickPrescribedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _prescribedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _prescribedDate = picked;
        // Shift validUntil forward if it's before the new prescribed date
        if (_validUntil != null && _validUntil!.isBefore(picked)) {
          _validUntil = picked.add(const Duration(days: 30));
        }
      });
    }
  }

  Future<void> _pickValidUntil() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil ?? _prescribedDate.add(const Duration(days: 30)),
      firstDate: _prescribedDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _validUntil = picked);
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ── Submit ───────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final items = _itemRows
        .where((r) => r.nameCtrl.text.trim().isNotEmpty)
        .map((r) => {
              'itemName': r.nameCtrl.text.trim(),
              'quantity':
                  double.tryParse(r.qtyCtrl.text.trim()) ?? 1.0,
              if (r.dosageCtrl.text.trim().isNotEmpty)
                'dosageInstructions': r.dosageCtrl.text.trim(),
            })
        .toList();

    final payload = {
      'contactId': widget.contactId,
      if (widget.receiptId != null) 'receiptId': widget.receiptId,
      'prescriptionNumber': _rxNumberCtrl.text.trim(),
      if (_doctorNameCtrl.text.trim().isNotEmpty)
        'doctorName': _doctorNameCtrl.text.trim(),
      if (_doctorRegCtrl.text.trim().isNotEmpty)
        'doctorRegNumber': _doctorRegCtrl.text.trim(),
      'prescribedDate': _prescribedDate.toIso8601String().substring(0, 10),
      if (_validUntil != null)
        'validUntil': _validUntil!.toIso8601String().substring(0, 10),
      if (_notesCtrl.text.trim().isNotEmpty)
        'notes': _notesCtrl.text.trim(),
      if (items.isNotEmpty) 'items': items,
    };

    try {
      await ref.read(prescriptionRepositoryProvider).create(payload);
      if (!mounted) return;
      // Invalidate contact prescriptions cache so history screen refreshes
      ref.invalidate(contactPrescriptionsProvider(widget.contactId));
      Navigator.of(context).pop(true); // pop with success flag
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiErrorParser.message(e)),
          backgroundColor: KColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.contactName != null
              ? 'Add Prescription — ${widget.contactName}'
              : 'Add Prescription',
          style: KTypography.h3,
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _submit,
              child: const Text('Save'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(KSpacing.md),
          children: [
            // ── Core fields ──────────────────────────────────
            _SectionHeader(title: 'Prescription Details'),
            const SizedBox(height: KSpacing.sm),
            TextFormField(
              controller: _rxNumberCtrl,
              decoration: const InputDecoration(
                labelText: 'Prescription No. (Rx) *',
                hintText: 'e.g. RX-20240501-001',
                prefixIcon: Icon(Icons.numbers_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Rx number is required' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: KSpacing.md),
            TextFormField(
              controller: _doctorNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Doctor Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: KSpacing.md),
            TextFormField(
              controller: _doctorRegCtrl,
              decoration: const InputDecoration(
                labelText: 'Doctor Reg. Number',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: KSpacing.md),

            // ── Dates ─────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _DateTile(
                    label: 'Prescribed Date',
                    date: _prescribedDate,
                    onTap: _pickPrescribedDate,
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: _DateTile(
                    label: 'Valid Until',
                    date: _validUntil,
                    onTap: _pickValidUntil,
                    placeholder: 'Optional',
                  ),
                ),
              ],
            ),
            const SizedBox(height: KSpacing.md),

            // ── Notes ─────────────────────────────────────────
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: KSpacing.lg),

            // ── Items section ──────────────────────────────────
            _SectionHeader(title: 'Prescribed Items'),
            const SizedBox(height: KSpacing.sm),
            ..._itemRows.asMap().entries.map((entry) {
              final idx = entry.key;
              final row = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.sm),
                child: _ItemRowWidget(
                  row: row,
                  index: idx,
                  canRemove: _itemRows.length > 1,
                  onRemove: () => setState(() {
                    row.dispose();
                    _itemRows.removeAt(idx);
                  }),
                ),
              );
            }),
            const SizedBox(height: KSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => setState(() => _itemRows.add(_PrescriptionItemRow())),
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            ),
            const SizedBox(height: KSpacing.xl),
          ],
        ),
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: KTypography.labelLarge
            .copyWith(color: KColors.textSecondary, letterSpacing: 0.5));
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final String? placeholder;

  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
    this.placeholder,
  });

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          date != null ? _fmt(date!) : (placeholder ?? '—'),
          style: date != null
              ? KTypography.bodyMedium
              : KTypography.bodyMedium.copyWith(color: KColors.textSecondary),
        ),
      ),
    );
  }
}

// ── Item row model ────────────────────────────────────────────

class _PrescriptionItemRow {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController(text: '1');
  final TextEditingController dosageCtrl = TextEditingController();

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    dosageCtrl.dispose();
  }
}

class _ItemRowWidget extends StatelessWidget {
  final _PrescriptionItemRow row;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;

  const _ItemRowWidget({
    required this.row,
    required this.index,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(KSpacing.sm, KSpacing.xs, KSpacing.xs, KSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Item ${index + 1}',
                    style: KTypography.labelMedium
                        .copyWith(color: KColors.textSecondary)),
                const Spacer(),
                if (canRemove)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        size: 20, color: KColors.error),
                    tooltip: 'Remove item',
                    onPressed: onRemove,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: KSpacing.xs),
            TextFormField(
              controller: row.nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Medicine / Item Name',
                isDense: true,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: KSpacing.xs),
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: row.qtyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      isDense: true,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*')),
                    ],
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: TextFormField(
                    controller: row.dosageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dosage / Instructions',
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
