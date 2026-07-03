import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/customer_receipt_repository.dart';

const _paymentMethods = [
  ('BANK_TRANSFER', 'Bank Transfer', Icons.account_balance),
  ('UPI', 'UPI', Icons.qr_code),
  ('CASH', 'Cash', Icons.money),
  ('CHEQUE', 'Cheque', Icons.receipt_long),
  ('CARD', 'Card', Icons.credit_card),
];

const _payableStatuses = {'SENT', 'PARTIALLY_PAID', 'OVERDUE'};

/// Record one lump-sum collection from a customer, allocated across many open
/// invoices. Any excess over the allocations is parked as a customer advance.
class RecordCustomerReceiptScreen extends ConsumerStatefulWidget {
  const RecordCustomerReceiptScreen({super.key});

  @override
  ConsumerState<RecordCustomerReceiptScreen> createState() =>
      _RecordCustomerReceiptScreenState();
}

class _RecordCustomerReceiptScreenState
    extends ConsumerState<RecordCustomerReceiptScreen> {
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  EntityOption? _customer;
  String _paymentMethod = 'BANK_TRANSFER';
  DateTime _receiptDate = DateTime.now();

  List<Map<String, dynamic>> _invoices = const [];
  final Map<String, TextEditingController> _allocControllers = {};

  bool _loadingInvoices = false;
  bool _submitting = false;
  String? _invoiceError;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    for (final c in _allocControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Derived totals ────────────────────────────────────────

  double get _received => double.tryParse(_amountController.text.trim()) ?? 0;

  double _alloc(String invoiceId) =>
      double.tryParse(_allocControllers[invoiceId]?.text.trim() ?? '') ?? 0;

  double get _totalAllocated =>
      _invoices.fold(0, (sum, inv) => sum + _alloc(inv['id'] as String));

  double get _advance => _received - _totalAllocated;

  // ── Data loading ──────────────────────────────────────────

  Future<List<EntityOption>> _searchCustomers(String query) async {
    final res = await ref.read(apiClientProvider).get(
      ApiConfig.contacts,
      queryParameters: {'type': 'CUSTOMER', 'search': query, 'size': 20},
    );
    final data = res.data as Map<String, dynamic>;
    final content = ((data['data'] as Map?)?['content'] as List?) ?? const [];
    return content.map((c) {
      final m = c as Map<String, dynamic>;
      final outstanding = (m['outstandingAr'] as num?)?.toDouble() ?? 0;
      return EntityOption(
        id: m['id'] as String,
        label: (m['displayName'] ?? m['name'] ?? 'Customer') as String,
        subtitle: outstanding > 0
            ? 'Outstanding ${CurrencyFormatter.format(outstanding)}'
            : null,
        raw: m,
      );
    }).toList();
  }

  Future<void> _onCustomerPicked(EntityOption? customer) async {
    // reset allocation state on customer change
    for (final c in _allocControllers.values) {
      c.dispose();
    }
    _allocControllers.clear();
    setState(() {
      _customer = customer;
      _invoices = const [];
      _invoiceError = null;
    });
    if (customer == null) return;

    setState(() => _loadingInvoices = true);
    try {
      final res = await ref.read(apiClientProvider).get(
        ApiConfig.invoicesByContact(customer.id),
        queryParameters: {'size': 100, 'sort': 'invoiceDate,asc'},
      );
      final data = res.data as Map<String, dynamic>;
      final content = ((data['data'] as Map?)?['content'] as List?) ?? const [];
      final open = content
          .cast<Map<String, dynamic>>()
          .where((inv) =>
              _payableStatuses.contains(inv['status']) &&
              ((inv['balanceDue'] as num?)?.toDouble() ?? 0) > 0)
          .toList();
      for (final inv in open) {
        _allocControllers[inv['id'] as String] = TextEditingController()
          ..addListener(() => setState(() {}));
      }
      setState(() => _invoices = open);
    } catch (e) {
      setState(() => _invoiceError = '$e');
    } finally {
      if (mounted) setState(() => _loadingInvoices = false);
    }
  }

  // ── Allocation helpers ────────────────────────────────────

  void _autoAllocate() {
    var remaining = _received;
    if (remaining <= 0) {
      _toast('Enter the amount received first');
      return;
    }
    for (final inv in _invoices) {
      final id = inv['id'] as String;
      final balance = (inv['balanceDue'] as num?)?.toDouble() ?? 0;
      final give =
          remaining <= 0 ? 0.0 : (remaining < balance ? remaining : balance);
      _allocControllers[id]!.text = give > 0 ? give.toStringAsFixed(2) : '';
      remaining -= give;
    }
    setState(() {});
  }

  void _clearAllocations() {
    for (final c in _allocControllers.values) {
      c.text = '';
    }
    setState(() {});
  }

  String? _validationError() {
    if (_customer == null) return 'Select a customer';
    if (_received <= 0) return 'Enter the amount received';
    if (_advance < -0.001) {
      return 'Allocations (${CurrencyFormatter.format(_totalAllocated)}) exceed '
          'the amount received (${CurrencyFormatter.format(_received)})';
    }
    for (final inv in _invoices) {
      final id = inv['id'] as String;
      final balance = (inv['balanceDue'] as num?)?.toDouble() ?? 0;
      if (_alloc(id) - balance > 0.001) {
        return 'Allocation to ${inv['invoiceNumber']} exceeds its balance';
      }
    }
    return null;
  }

  Future<void> _submit() async {
    final err = _validationError();
    if (err != null) {
      _toast(err);
      return;
    }
    final allocations = <Map<String, dynamic>>[];
    for (final inv in _invoices) {
      final id = inv['id'] as String;
      final amt = _alloc(id);
      if (amt > 0) {
        allocations.add({'invoiceId': id, 'amountApplied': amt});
      }
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(customerReceiptRepositoryProvider);
      final result = await repo.recordReceipt(
        contactId: _customer!.id,
        amount: _received,
        paymentMethod: _paymentMethod,
        receiptDate: DateFormatter.api(_receiptDate),
        referenceNumber: _referenceController.text.trim(),
        notes: _notesController.text.trim(),
        allocations: allocations,
      );
      if (!mounted) return;
      final number = result['receiptNumber'] ?? 'Receipt';
      final advance = (result['advanceAmount'] as num?)?.toDouble() ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(advance > 0
            ? '$number recorded — ${CurrencyFormatter.format(advance)} kept as advance'
            : '$number recorded'),
        backgroundColor: KColors.success,
      ));
      context.pop(true);
    } catch (e) {
      if (mounted) _toast('Failed to record receipt: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── UI ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record Customer Receipt')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KEntityPickerField(
              label: 'Customer',
              pickerTitle: 'Select customer',
              hint: 'Search customers…',
              icon: Icons.person_outline,
              value: _customer,
              search: _searchCustomers,
              onChanged: _onCustomerPicked,
            ),
            const SizedBox(height: KSpacing.md),
            KTextField(
              label: 'Amount received',
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              prefixIcon: Icons.currency_rupee,
              hint: '0.00',
            ),
            const SizedBox(height: KSpacing.md),
            Row(
              children: [
                Expanded(child: _methodDropdown()),
                const SizedBox(width: KSpacing.md),
                Expanded(child: _datePicker()),
              ],
            ),
            const SizedBox(height: KSpacing.md),
            KTextField(
              label: 'Reference (UTR / cheque no.)',
              controller: _referenceController,
              hint: 'Optional',
            ),
            const SizedBox(height: KSpacing.lg),
            _invoicesSection(),
            const SizedBox(height: KSpacing.md),
            KTextField(
              label: 'Notes',
              controller: _notesController,
              hint: 'Optional',
              maxLines: 2,
            ),
            const SizedBox(height: KSpacing.lg),
            _summaryCard(),
            const SizedBox(height: KSpacing.lg),
            KButton(
              label: 'Record receipt',
              icon: Icons.check,
              isLoading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _paymentMethod,
      decoration: const InputDecoration(
        labelText: 'Method',
        border: OutlineInputBorder(),
      ),
      items: _paymentMethods
          .map((m) => DropdownMenuItem(
                value: m.$1,
                child: Row(children: [
                  Icon(m.$3, size: 18, color: KColors.textSecondary),
                  const SizedBox(width: KSpacing.sm),
                  Text(m.$2),
                ]),
              ))
          .toList(),
      onChanged: (v) => setState(() => _paymentMethod = v ?? _paymentMethod),
    );
  }

  Widget _datePicker() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _receiptDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        if (picked != null) setState(() => _receiptDate = picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Receipt date',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(DateFormatter.display(_receiptDate),
            style: KTypography.bodyMedium),
      ),
    );
  }

  Widget _invoicesSection() {
    if (_customer == null) {
      return KCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: KSpacing.md),
          child: Text('Select a customer to see their open invoices.',
              style: KTypography.bodyMedium
                  .copyWith(color: KColors.textSecondary)),
        ),
      );
    }
    if (_loadingInvoices) {
      return const Padding(
        padding: EdgeInsets.all(KSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_invoiceError != null) {
      return KErrorView(
        message: _invoiceError!,
        onRetry: () => _onCustomerPicked(_customer),
      );
    }
    if (_invoices.isEmpty) {
      return const KEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No open invoices',
        subtitle: 'The full amount will be recorded as a customer advance.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Open invoices', style: KTypography.labelLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: _autoAllocate,
              icon: const Icon(Icons.auto_fix_high, size: 16),
              label: const Text('Auto-allocate'),
            ),
            TextButton(
                onPressed: _clearAllocations, child: const Text('Clear')),
          ],
        ),
        const SizedBox(height: KSpacing.sm),
        ..._invoices.map(_invoiceRow),
      ],
    );
  }

  Widget _invoiceRow(Map<String, dynamic> inv) {
    final id = inv['id'] as String;
    final balance = (inv['balanceDue'] as num?)?.toDouble() ?? 0;
    final over = _alloc(id) - balance > 0.001;
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: KCard(
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(inv['invoiceNumber']?.toString() ?? '—',
                      style: KTypography.labelMedium),
                  const SizedBox(height: 2),
                  Row(children: [
                    KStatusChip(status: inv['status']?.toString() ?? ''),
                    const SizedBox(width: KSpacing.sm),
                    Text('Due ${CurrencyFormatter.format(balance)}',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary)),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: KSpacing.sm),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _allocControllers[id],
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '0.00',
                  prefixText: '₹ ',
                  errorText: over ? 'Over balance' : null,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    final advancePositive = _advance > 0.001;
    final overAllocated = _advance < -0.001;
    return KCard(
      child: Column(
        children: [
          _summaryRow('Received', _received, KColors.textPrimary),
          const Divider(height: KSpacing.md),
          _summaryRow(
              'Allocated to invoices', _totalAllocated, KColors.textSecondary),
          const Divider(height: KSpacing.md),
          _summaryRow(
            overAllocated ? 'Over-allocated' : 'Advance (unapplied)',
            _advance,
            overAllocated
                ? KColors.error
                : (advancePositive ? KColors.warning : KColors.textSecondary),
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, Color color,
      {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: (bold ? KTypography.labelLarge : KTypography.bodyMedium)
                .copyWith(color: color)),
        Text(CurrencyFormatter.format(value),
            style: (bold ? KTypography.labelLarge : KTypography.bodyMedium)
                .copyWith(color: color)),
      ],
    );
  }
}
