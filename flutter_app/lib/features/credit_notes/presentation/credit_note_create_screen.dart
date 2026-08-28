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
import '../../../core/utils/form_error_handler.dart';
import '../../../routing/app_router.dart';
import '../../contacts/presentation/contact_picker_sheet.dart';
import '../../invoices/data/invoice_repository.dart';
import '../../tax_groups/presentation/widgets/tax_group_picker.dart';
import '../data/credit_note_repository.dart';
import '../data/credit_note_providers.dart';

class CreditNoteCreateScreen extends ConsumerStatefulWidget {
  const CreditNoteCreateScreen({super.key});

  @override
  ConsumerState<CreditNoteCreateScreen> createState() =>
      _CreditNoteCreateScreenState();
}

class _CreditNoteCreateScreenState extends ConsumerState<CreditNoteCreateScreen>
    with FormErrorHandler {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // Header fields
  String? _selectedContactId;
  DateTime _creditNoteDate = DateTime.now();
  final _reasonController = TextEditingController();
  final _placeOfSupplyController = TextEditingController();
  final _customerController = TextEditingController();
  bool _isLoadingInvoices = false;
  List<Map<String, dynamic>> _customerInvoices = [];
  Map<String, dynamic>? _selectedInvoice;

  // Line items
  final List<_LineItem> _lines = [_LineItem()];

  @override
  void dispose() {
    _reasonController.dispose();
    _placeOfSupplyController.dispose();
    _customerController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  double get _subtotal =>
      _lines.fold(0.0, (sum, line) => sum + line.taxableAmount);

  double get _taxTotal => _lines.fold(0.0, (sum, line) => sum + line.taxAmount);

  double get _grandTotal => _subtotal + _taxTotal;

  Future<void> _submit() async {
    // Guard: Ctrl+Enter can invoke this directly while a submit is in
    // flight; without this check a second press creates a duplicate document.
    if (_isSubmitting) return;
    clearServerErrors();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedContactId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }
    if (_selectedInvoice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the original invoice')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(creditNoteRepositoryProvider);
      final data = {
        'contactId': _selectedContactId,
        if (_selectedInvoice?['id'] != null)
          'invoiceId': _selectedInvoice!['id'].toString(),
        'creditNoteDate': DateFormatter.api(_creditNoteDate),
        'reason': _reasonController.text.trim(),
        if (_placeOfSupplyController.text.trim().isNotEmpty)
          'placeOfSupply': _placeOfSupplyController.text.trim(),
        'lines': _lines
            .map((line) => {
                  'description': line.descriptionController.text.trim(),
                  if (line.hsnController.text.trim().isNotEmpty)
                    'hsnCode': line.hsnController.text.trim(),
                  'quantity': double.tryParse(line.qtyController.text) ?? 1,
                  'unitPrice': double.tryParse(line.priceController.text) ?? 0,
                  'gstRate': line.gstRate,
                  'accountCode': line.accountCode,
                  if (line.itemId != null) 'itemId': line.itemId,
                  if (line.batchId != null) 'batchId': line.batchId,
                  if (line.taxGroupId != null) 'taxGroupId': line.taxGroupId,
                })
            .toList(),
      };

      await repo.createCreditNote(data);
      ref.invalidate(creditNoteListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credit note created')),
        );
        context.go(Routes.creditNotes);
      }
    } catch (e) {
      if (mounted) handleSaveError(e, _formKey);
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

  Future<void> _pickCustomer() async {
    final picked = await showContactPicker(context, showQuickCreate: true);
    if (picked == null || !mounted) return;
    final name = _contactName(picked);
    setState(() {
      _selectedContactId = picked['id']?.toString();
      _customerController.text = name;
      _selectedInvoice = null;
      _customerInvoices = [];
      _replaceLines([_LineItem()]);
      final placeOfSupply = picked['placeOfSupply']?.toString();
      final billingStateCode = picked['billingStateCode']?.toString();
      if (_placeOfSupplyController.text.trim().isEmpty) {
        _placeOfSupplyController.text = placeOfSupply ?? billingStateCode ?? '';
      }
    });
    await _loadCustomerInvoices();
  }

  Future<void> _loadCustomerInvoices() async {
    final contactId = _selectedContactId;
    if (contactId == null) return;

    setState(() => _isLoadingInvoices = true);
    try {
      final repo = ref.read(invoiceRepositoryProvider);
      final response = await repo.listInvoicesByContact(contactId);
      final invoices =
          _extractList(response).where(_isReturnableInvoice).toList();
      if (!mounted) return;
      setState(() => _customerInvoices = invoices);
    } catch (_) {
      if (!mounted) return;
      setState(() => _customerInvoices = []);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load customer invoices')),
      );
    } finally {
      if (mounted) setState(() => _isLoadingInvoices = false);
    }
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic> response) {
    final data = response['data'] ?? response;
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    if (data is Map<String, dynamic>) {
      final content = data['content'];
      if (content is List) {
        return content.whereType<Map<String, dynamic>>().toList();
      }
    }
    return [];
  }

  bool _isReturnableInvoice(Map<String, dynamic> invoice) {
    final status = invoice['status']?.toString().toUpperCase();
    return const {'SENT', 'PARTIALLY_PAID', 'OVERDUE', 'PAID'}.contains(status);
  }

  void _selectInvoice(Map<String, dynamic> invoice) {
    final rawLines = invoice['lines'];
    final copiedLines = <_LineItem>[];
    if (rawLines is List) {
      for (final raw in rawLines.whereType<Map<String, dynamic>>()) {
        copiedLines.add(_LineItem.fromInvoiceLine(raw));
      }
    }
    setState(() {
      _selectedInvoice = invoice;
      _replaceLines(copiedLines.isEmpty ? [_LineItem()] : copiedLines);
    });
  }

  void _replaceLines(List<_LineItem> nextLines) {
    for (final line in _lines) {
      line.dispose();
    }
    _lines
      ..clear()
      ..addAll(nextLines);
  }

  @override
  Widget build(BuildContext context) {
    return KKeyboardFormWrapper(
      onSubmit: _submit,
      onCancel: () => context.go(Routes.creditNotes),
      child: Scaffold(
      appBar: AppBar(
        title: const Text('New Credit Note'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: KSpacing.pagePadding,
          children: [
            _buildWorkflowHeader(),
            KSpacing.vGapMd,

            // Customer + Date side-by-side
            KCompactRow(children: [
              _buildCustomerPicker(),
              KTextField(
                label: 'Credit Note Date',
                controller: TextEditingController(
                  text: DateFormatter.display(_creditNoteDate),
                ),
                readOnly: true,
                prefixIcon: Icons.calendar_today,
                onTap: _pickDate,
              ),
            ]),
            KSpacing.vGapSm,

            // Reason + Place of Supply side-by-side
            KCompactRow(flex: const [
              3,
              1
            ], children: [
              KTextField(
                label: 'Reason *',
                hint: 'e.g., Goods returned, Pricing error',
                controller: _reasonController,
                serverError: serverErrors['reason'],
                validator: (v) => fieldError(
                  'reason',
                  (v == null || v.trim().isEmpty) ? 'Reason is required' : null,
                ),
              ),
              KTextField(
                label: 'State Code',
                hint: 'e.g. 29',
                controller: _placeOfSupplyController,
                serverError: serverErrors['placeOfSupply'],
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
              ),
            ]),
            KSpacing.vGapSm,

            // ── Line Items ──
            _buildSourceInvoiceSection(),
            KSpacing.vGapSm,

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Return Lines', style: KTypography.h3),
                if (_selectedInvoice != null)
                  TextButton.icon(
                    onPressed: _addLine,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Adjustment'),
                  ),
              ],
            ),
            KSpacing.vGapSm,

            if (_selectedInvoice == null)
              KCard(
                borderColor: KColors.divider,
                child: Row(
                  children: [
                    const Icon(Icons.assignment_return_outlined,
                        color: KColors.textHint),
                    KSpacing.hGapSm,
                    Expanded(
                      child: Text(
                        'Select the original invoice to populate return lines.',
                        style: KTypography.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_lines.length, (i) => _buildLineCard(i)),

            KSpacing.vGapLg,

            // ── Totals ──
            _buildImpactPreviewCard(),
            KSpacing.vGapMd,

            KCard(
              child: Column(
                children: [
                  _TotalRow(
                    label: 'Subtotal',
                    amount: _subtotal,
                  ),
                  _TotalRow(
                    label: 'Tax (GST)',
                    amount: _taxTotal,
                  ),
                  const Divider(),
                  _TotalRow(
                    label: 'Total',
                    amount: _grandTotal,
                    bold: true,
                    color: KColors.error,
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
    ),
    );
  }

  Widget _buildWorkflowHeader() {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sales Return Workflow', style: KTypography.h2),
          KSpacing.vGapSm,
          Text(
            'Start from the original invoice so customer balance, GST, and inventory stay linked.',
            style:
                KTypography.bodyMedium.copyWith(color: KColors.textSecondary),
          ),
          KSpacing.vGapMd,
          Wrap(
            spacing: KSpacing.sm,
            runSpacing: KSpacing.sm,
            children: [
              _StepPill(
                number: 1,
                label: 'Customer',
                active: _selectedContactId == null,
                done: _selectedContactId != null,
              ),
              _StepPill(
                number: 2,
                label: 'Invoice',
                active: _selectedContactId != null && _selectedInvoice == null,
                done: _selectedInvoice != null,
              ),
              _StepPill(
                number: 3,
                label: 'Return qty',
                active: _selectedInvoice != null,
                done: _grandTotal > 0,
              ),
              _StepPill(
                number: 4,
                label: 'Draft',
                active: _grandTotal > 0,
                done: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImpactPreviewCard() {
    final returnedQty = _lines.fold<double>(0, (sum, line) => sum + line._qty);
    final itemLineCount = _lines.where((line) => line.itemId != null).length;
    final invoiceNumber = _selectedInvoice?['invoiceNumber']?.toString();

    return KCard(
      title: 'Impact Preview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (invoiceNumber != null) ...[
            _ImpactLine(
              icon: Icons.link_rounded,
              label: 'Linked document',
              value: invoiceNumber,
            ),
            KSpacing.vGapSm,
          ],
          _ImpactLine(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Customer balance reduction',
            valueWidget: KMoney(_grandTotal, size: KMoneySize.medium),
            color: KColors.success,
          ),
          KSpacing.vGapSm,
          _ImpactLine(
            icon: Icons.receipt_long_outlined,
            label: 'Revenue reversal',
            valueWidget: KMoney(_subtotal, size: KMoneySize.medium),
            color: KColors.error,
          ),
          KSpacing.vGapSm,
          _ImpactLine(
            icon: Icons.percent_rounded,
            label: 'GST reversal',
            valueWidget: KMoney(_taxTotal, size: KMoneySize.medium),
            color: KColors.warning,
          ),
          KSpacing.vGapSm,
          _ImpactLine(
            icon: Icons.inventory_2_outlined,
            label: 'Stock return lines',
            value: itemLineCount == 0
                ? 'No inventory lines'
                : '$itemLineCount line(s), ${_formatQty(returnedQty)} qty',
            color: itemLineCount == 0 ? KColors.textSecondary : KColors.info,
          ),
          KSpacing.vGapMd,
          Text(
            'This creates a draft. The accounting and stock impact happen when the credit note is issued.',
            style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _formatQty(double value) {
    if (value.truncateToDouble() == value) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  String? _lineServerError(int index, String field) {
    return serverErrors['lines[$index].$field'] ??
        serverErrors['lines.$index.$field'] ??
        serverErrors['lines[$index][$field]'] ??
        serverErrors[field];
  }

  Widget _buildCustomerPicker() {
    return KTextField(
      label: 'Customer *',
      hint: 'Select or create customer',
      controller: _customerController,
      readOnly: true,
      prefixIcon: Icons.person_outline,
      suffixIcon: Icons.chevron_right,
      onTap: _pickCustomer,
      serverError: serverErrors['contactId'],
      validator: (_) => fieldError(
        'contactId',
        _selectedContactId == null ? 'Select a customer' : null,
      ),
    );
  }

  String _contactName(Map<String, dynamic> contact) {
    for (final key in const [
      'displayName',
      'companyName',
      'name',
      'fullName',
      'contactName',
    ]) {
      final value = contact[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    final first = contact['firstName']?.toString().trim() ?? '';
    final last = contact['lastName']?.toString().trim() ?? '';
    final full = [first, last].where((s) => s.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;
    return 'Customer';
  }

  Widget _buildSourceInvoiceSection() {
    if (_selectedContactId == null) {
      return const SizedBox.shrink();
    }
    if (_isLoadingInvoices) {
      return const KCard(
        child: KLoading(message: 'Loading customer invoices...'),
      );
    }
    if (_customerInvoices.isEmpty) {
      return KCard(
        borderColor: KColors.warning,
        child: Row(
          children: [
            const Icon(Icons.receipt_long_outlined, color: KColors.warning),
            KSpacing.hGapSm,
            Expanded(
              child: Text(
                'No posted invoices found for this customer. Select a customer with posted invoices to link the return and auto-fill items.',
                style: KTypography.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Original Invoice *', style: KTypography.labelLarge),
          KSpacing.vGapSm,
          ..._customerInvoices.map(_buildInvoiceOption),
        ],
      ),
    );
  }

  Widget _buildInvoiceOption(Map<String, dynamic> invoice) {
    final id = invoice['id']?.toString();
    final selected = id != null && id == _selectedInvoice?['id']?.toString();
    final number = invoice['invoiceNumber']?.toString() ?? 'Invoice';
    final date = invoice['invoiceDate']?.toString() ?? '--';
    final status = invoice['status']?.toString() ?? '--';
    final total = (invoice['totalAmount'] as num?)?.toDouble() ?? 0;
    final balance = (invoice['balanceDue'] as num?)?.toDouble() ?? 0;

    return InkWell(
      onTap: () => _selectInvoice(invoice),
      borderRadius: KSpacing.borderRadiusSm,
      child: Container(
        margin: const EdgeInsets.only(bottom: KSpacing.xs),
        padding: const EdgeInsets.all(KSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: KSpacing.borderRadiusSm,
          border: Border.all(
            color: selected ? KColors.primary : KColors.divider,
          ),
          color: selected ? KColors.primary.withValues(alpha: 0.06) : null,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? KColors.primary : KColors.textHint,
            ),
            KSpacing.hGapSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(number, style: KTypography.labelLarge),
                  KSpacing.vGapXs,
                  Text('$date - $status', style: KTypography.bodySmall),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                KMoney(total, size: KMoneySize.small),
                KSpacing.vGapXs,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Due ', style: KTypography.bodySmall),
                    KMoney(balance, size: KMoneySize.small),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineCard(int index) {
    final line = _lines[index];

    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.xs),
      padding: const EdgeInsets.all(KSpacing.sm),
      borderColor: KColors.divider,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Return Item ${index + 1}', style: KTypography.labelLarge),
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
          KSpacing.vGapXs,
          KTextField(
            label: 'Description *',
            controller: line.descriptionController,
            readOnly: line.fromInvoice,
            serverError: _lineServerError(index, 'description'),
            validator: (v) => fieldError(
              'lines[$index].description',
              (v == null || v.trim().isEmpty) ? 'Description required' : null,
            ),
          ),
          KSpacing.vGapXs,
          KCompactRow(flex: const [
            1,
            1,
            2
          ], children: [
            KTextField(
              label: 'HSN',
              hint: 'Optional',
              controller: line.hsnController,
              serverError: _lineServerError(index, 'hsnCode'),
              keyboardType: TextInputType.number,
            ),
            KTextField(
              label: 'Qty',
              controller: line.qtyController,
              serverError: _lineServerError(index, 'quantity'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final val = double.tryParse(v ?? '');
                String? clientError;
                if (val == null || val <= 0) clientError = 'Invalid';
                if (val != null &&
                    line.maxQuantity != null &&
                    val > line.maxQuantity!) {
                  clientError = 'Max ${line.maxQuantity!.toStringAsFixed(2)}';
                }
                return fieldError('lines[$index].quantity', clientError);
              },
            ),
            KTextField.amount(
              label: 'Unit Price',
              controller: line.priceController,
              readOnly: line.fromInvoice,
              serverError: _lineServerError(index, 'unitPrice'),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final val = double.tryParse(v ?? '');
                return fieldError(
                  'lines[$index].unitPrice',
                  val == null || val < 0 ? 'Invalid' : null,
                );
              },
            ),
          ]),
          KSpacing.vGapXs,
          Row(
            children: [
              Expanded(
                child: TaxGroupPicker(
                  value: line.taxGroupId,
                  label: 'Tax',
                  onChanged: line.fromInvoice
                      ? (_) {}
                      : (group) => setState(() {
                            line.taxGroupId = group?.id;
                            line.gstRate = group?.totalRate ?? 0;
                          }),
                ),
              ),
              KSpacing.hGapMd,
              Text(
                CurrencyFormatter.formatIndian(line.lineTotal),
                style: KTypography.amountSmall.copyWith(
                  color: KColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  final int number;
  final String label;
  final bool active;
  final bool done;

  const _StepPill({
    required this.number,
    required this.label,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final color = done
        ? KColors.success
        : active
            ? KColors.primary
            : KColors.textHint;
    final bg = done
        ? KColors.successLight
        : active
            ? KColors.primarySoft
            : KColors.draftBg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: KSpacing.borderRadiusMd,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: color,
            child: done
                ? const Icon(Icons.check, size: 13, color: Colors.white)
                : Text(
                    '$number',
                    style: KTypography.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          KSpacing.hGapSm,
          Text(
            label,
            style: KTypography.labelMedium.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _ImpactLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueWidget;
  final Color? color;

  const _ImpactLine({
    required this.icon,
    required this.label,
    this.value,
    this.valueWidget,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? KColors.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: KSpacing.borderRadiusMd,
          ),
          child: Icon(icon, size: 17, color: accent),
        ),
        KSpacing.hGapSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: KTypography.bodySmall.copyWith(
                  color: KColors.textSecondary,
                ),
              ),
              if (valueWidget != null)
                valueWidget!
              else if (value != null)
                Text(
                  value!,
                  style: KTypography.labelLarge.copyWith(
                    color: KColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Mutable line item model for the create form.
class _LineItem {
  final descriptionController = TextEditingController();
  final hsnController = TextEditingController();
  final qtyController = TextEditingController(text: '1');
  final priceController = TextEditingController();
  double gstRate = 0.0;
  String accountCode = '4000';
  String? taxGroupId;
  String? itemId;
  String? batchId;
  double? maxQuantity;
  bool fromInvoice = false;

  _LineItem();

  factory _LineItem.fromInvoiceLine(Map<String, dynamic> source) {
    final line = _LineItem();
    final quantity = (source['quantity'] as num?)?.toDouble() ?? 1;
    final unitPrice = (source['unitPrice'] as num?)?.toDouble() ?? 0;

    line.descriptionController.text = source['description']?.toString() ?? '';
    line.hsnController.text = source['hsnCode']?.toString() ?? '';
    line.qtyController.text = quantity
        .toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 2);
    line.priceController.text = unitPrice.toStringAsFixed(2);
    line.gstRate = (source['gstRate'] as num?)?.toDouble() ?? 0;
    line.accountCode = source['accountCode']?.toString() ?? '4000';
    line.taxGroupId = source['taxGroupId']?.toString();
    line.itemId = source['itemId']?.toString();
    line.batchId = source['batchId']?.toString();
    line.maxQuantity = quantity;
    line.fromInvoice = true;
    return line;
  }

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
  final num amount;
  final bool bold;
  final Color? color;

  const _TotalRow({
    required this.label,
    required this.amount,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: bold
                ? KTypography.labelLarge.copyWith(fontWeight: FontWeight.w700)
                : KTypography.bodyMedium,
          ),
          KMoney(
            amount,
            size: bold ? KMoneySize.medium : KMoneySize.small,
            style: color != null
                ? TextStyle(
                    color: color,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  )
                : (bold ? const TextStyle(fontWeight: FontWeight.w700) : null),
          ),
        ],
      ),
    );
  }
}
