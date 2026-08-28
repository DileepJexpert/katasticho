import 'package:flutter/material.dart';
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
import '../../contacts/presentation/contact_picker_sheet.dart';
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

  String? _selectedContactId;
  String _contactName = '';
  String? _contactPhone;
  double? _outstandingAr;

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

  // ── Customer Picking ──────────────────────────────────────

  Future<void> _openCustomerPicker() async {
    final picked = await showContactPicker(context, contactType: 'CUSTOMER');
    if (picked == null || !mounted) return;

    for (final c in _allocControllers.values) {
      c.dispose();
    }
    _allocControllers.clear();

    final name = picked['displayName'] ??
        picked['companyName'] ??
        picked['name'] ??
        'Customer';
    final phone = picked['phone'] ?? picked['mobile'];
    final outstanding = (picked['outstandingAr'] as num?)?.toDouble();

    setState(() {
      _selectedContactId = picked['id']?.toString();
      _contactName = name.toString();
      _contactPhone = phone?.toString();
      _outstandingAr = outstanding;
      _invoices = const [];
      _invoiceError = null;
    });

    if (_selectedContactId == null) return;

    setState(() => _loadingInvoices = true);
    try {
      final res = await ref.read(apiClientProvider).get(
        ApiConfig.invoicesByContact(_selectedContactId!),
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

  void _payInFull(String id, double balance) {
    _allocControllers[id]?.text = balance.toStringAsFixed(2);
    setState(() {});
  }

  String? _validationError() {
    if (_selectedContactId == null) return 'Please select a customer';
    if (_received <= 0) return 'Please enter the amount received';
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
        contactId: _selectedContactId!,
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
    final cs = Theme.of(context).colorScheme;
    final hasCustomer = _selectedContactId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Customer Receipt'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: KSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Card 1: Receipt Details ──
                  KCard(
                    title: 'Receipt Details',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer Picker Tile
                        InkWell(
                          onTap: _openCustomerPicker,
                          borderRadius: KSpacing.borderRadiusMd,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: KSpacing.sm,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: hasCustomer
                                  ? cs.primary.withValues(alpha: 0.04)
                                  : cs.surfaceContainerHighest.withValues(alpha: 0.3),
                              borderRadius: KSpacing.borderRadiusMd,
                              border: Border.all(
                                color: hasCustomer ? cs.primary : cs.outlineVariant,
                                width: hasCustomer ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: cs.primary.withValues(alpha: 0.12),
                                  child: Icon(
                                    hasCustomer ? Icons.person : Icons.person_add_alt_1,
                                    color: cs.primary,
                                    size: 18,
                                  ),
                                ),
                                KSpacing.hGapSm,
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        hasCustomer ? _contactName : 'Select Customer *',
                                        style: KTypography.labelLarge.copyWith(
                                          color: hasCustomer ? cs.onSurface : cs.error,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (hasCustomer)
                                        Text.rich(
                                          TextSpan(
                                            style: KTypography.bodySmall.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
                                            children: [
                                              if (_outstandingAr != null && _outstandingAr! > 0) ...[
                                                const TextSpan(text: 'Outstanding: '),
                                                TextSpan(
                                                  text: CurrencyFormatter.formatIndian(_outstandingAr!),
                                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                              if (_contactPhone != null && _contactPhone!.isNotEmpty) ...[
                                                if (_outstandingAr != null && _outstandingAr! > 0)
                                                  const TextSpan(text: ' · '),
                                                TextSpan(
                                                  text: _contactPhone!,
                                                  style: KTypography.mono(fontSize: 12),
                                                ),
                                              ],
                                            ],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      else
                                        Text(
                                          'Tap to pick customer from directory',
                                          style: KTypography.bodySmall.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  hasCustomer ? 'Change' : 'Browse',
                                  style: KTypography.labelMedium.copyWith(color: cs.primary),
                                ),
                                const Icon(Icons.chevron_right, size: 16),
                              ],
                            ),
                          ),
                        ),
                        KSpacing.vGapMd,

                        // Amount, Payment Method, Date
                        KCompactRow(
                          flex: const [3, 3, 3],
                          children: [
                            KTextField.amount(
                              label: 'Amount Received *',
                              controller: _amountController,
                            ),
                            KDropdownField<String>(
                              label: 'Payment Method',
                              value: _paymentMethod,
                              items: _paymentMethods
                                  .map((m) => DropdownMenuItem(
                                        value: m.$1,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(m.$3, size: 16, color: cs.onSurfaceVariant),
                                            const SizedBox(width: 6),
                                            Text(m.$2),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() => _paymentMethod = v ?? _paymentMethod),
                            ),
                            KDatePicker(
                              label: 'Receipt Date',
                              value: _receiptDate,
                              onChanged: (picked) => setState(() => _receiptDate = picked),
                            ),
                          ],
                        ),
                        KSpacing.vGapSm,

                        // Reference
                        KTextField(
                          label: 'Reference (UTR / Cheque No.)',
                          controller: _referenceController,
                          hint: 'e.g. UTR12345678, CHQ-9988',
                          prefixIcon: Icons.tag,
                        ),
                      ],
                    ),
                  ),
                  KSpacing.vGapMd,

                  // ── Card 2: Open Invoices & Allocation ──
                  KCard(
                    title: 'Open Invoices (${_invoices.length})',
                    action: _invoices.isNotEmpty
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              KButton(
                                label: 'Auto-allocate',
                                icon: Icons.auto_fix_high,
                                size: KButtonSize.small,
                                variant: KButtonVariant.outlined,
                                onPressed: _autoAllocate,
                              ),
                              KSpacing.hGapSm,
                              KButton(
                                label: 'Clear',
                                size: KButtonSize.small,
                                variant: KButtonVariant.text,
                                onPressed: _clearAllocations,
                              ),
                            ],
                          )
                        : null,
                    child: _buildInvoicesContent(),
                  ),
                  KSpacing.vGapMd,

                  // ── Card 3: Summary & Notes ──
                  KCard(
                    title: 'Notes & Summary',
                    child: KCompactRow(
                      flex: const [3, 2],
                      stackBelow: 720,
                      children: [
                        KTextField(
                          label: 'Notes & Remarks',
                          controller: _notesController,
                          hint: 'Optional receipt notes or bank details...',
                          maxLines: 4,
                        ),
                        Container(
                          padding: const EdgeInsets.all(KSpacing.sm),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
                            borderRadius: KSpacing.borderRadiusMd,
                            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _SummaryRow(
                                label: 'Amount Received',
                                value: _received,
                              ),
                              _SummaryRow(
                                label: 'Allocated to Invoices',
                                value: _totalAllocated,
                              ),
                              const Divider(height: 12),
                              _SummaryRow(
                                label: _advance < -0.001
                                    ? 'Over-allocated'
                                    : 'Advance (Unapplied)',
                                value: _advance,
                                bold: true,
                                color: _advance < -0.001
                                    ? KColors.error
                                    : (_advance > 0.001 ? KColors.warning : null),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  KSpacing.vGapXl,
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
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Amount Received', style: KTypography.bodySmall),
                      KMoney(_received, size: KMoneySize.medium),
                    ],
                  ),
                  const Spacer(),
                  KButton(
                    label: 'Cancel',
                    variant: KButtonVariant.outlined,
                    onPressed: () => context.pop(),
                  ),
                  KSpacing.hGapSm,
                  KButton(
                    label: 'Record Receipt',
                    icon: Icons.check,
                    isLoading: _submitting,
                    onPressed: _submitting ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicesContent() {
    if (_selectedContactId == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpacing.md),
        child: Center(
          child: Text(
            'Select a customer above to view and allocate open invoices.',
            style: KTypography.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
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
        onRetry: _openCustomerPicker,
      );
    }
    if (_invoices.isEmpty) {
      return const KEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No open invoices found',
        subtitle: 'The full received amount will be parked as a customer advance.',
      );
    }

    return Column(
      children: [
        ...List.generate(_invoices.length, (index) {
          final inv = _invoices[index];
          final id = inv['id'] as String;
          final invNum = inv['invoiceNumber']?.toString() ?? 'INV-??';
          final invDate = inv['invoiceDate']?.toString() ?? '';
          final total = (inv['total'] as num?)?.toDouble() ?? 0;
          final balance = (inv['balanceDue'] as num?)?.toDouble() ?? 0;
          final status = inv['status']?.toString() ?? 'SENT';
          final allocated = _alloc(id);
          final isOver = allocated - balance > 0.001;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(KSpacing.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
              borderRadius: KSpacing.borderRadiusMd,
              border: Border.all(
                color: isOver
                    ? KColors.error
                    : (allocated > 0
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
                        : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Invoice Details
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            invNum,
                            style: KTypography.mono(
                              fontSize: 13,
                              weight: FontWeight.w700,
                            ),
                          ),
                          KSpacing.hGapSm,
                          KStatusChip(status: status),
                        ],
                      ),
                      KSpacing.vGapXxs,
                      Row(
                        children: [
                          if (invDate.isNotEmpty) ...[
                            Text(invDate, style: KTypography.bodySmall),
                            Text(' · ', style: KTypography.bodySmall),
                          ],
                          Text('Total: ', style: KTypography.bodySmall),
                          KMoney(total, size: KMoneySize.small),
                          Text(' · ', style: KTypography.bodySmall),
                          Text('Due: ', style: KTypography.bodySmall),
                          KMoney(
                            balance,
                            size: KMoneySize.small,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                KSpacing.hGapSm,

                // Quick 'Full' CTA
                KButton(
                  label: 'Full',
                  size: KButtonSize.small,
                  variant: KButtonVariant.outlined,
                  onPressed: () => _payInFull(id, balance),
                ),
                KSpacing.hGapSm,

                // Allocation Input Box
                SizedBox(
                  width: 140,
                  child: KTextField.amount(
                    label: '',
                    controller: _allocControllers[id],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final num value;
  final bool bold;
  final Color? color;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: bold
                ? KTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color ?? cs.onSurface,
                  )
                : KTypography.bodyMedium.copyWith(
                    color: color ?? cs.onSurfaceVariant,
                  ),
          ),
          KMoney(
            value,
            size: bold ? KMoneySize.medium : KMoneySize.small,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
