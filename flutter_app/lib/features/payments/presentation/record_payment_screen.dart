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
import '../../invoices/data/invoice_repository.dart';
import '../../invoices/data/invoice_providers.dart';
import '../data/payment_repository.dart';

const _paymentMethods = [
  ('BANK_TRANSFER', 'Bank Transfer', Icons.account_balance),
  ('UPI', 'UPI', Icons.qr_code),
  ('CASH', 'Cash', Icons.money),
  ('CHEQUE', 'Cheque', Icons.receipt),
  ('CARD', 'Card', Icons.credit_card),
];

class RecordPaymentScreen extends ConsumerStatefulWidget {
  final String invoiceId;

  const RecordPaymentScreen({super.key, required this.invoiceId});

  @override
  ConsumerState<RecordPaymentScreen> createState() =>
      _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends ConsumerState<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  String _paymentMethod = 'BANK_TRANSFER';
  DateTime _paymentDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(paymentRepositoryProvider);
      await repo.recordPayment(widget.invoiceId, {
        'invoiceId': widget.invoiceId,
        'amount': double.tryParse(_amountController.text) ?? 0,
        'paymentMethod': _paymentMethod,
        'paymentDate': DateFormatter.api(_paymentDate),
        if (_referenceController.text.trim().isNotEmpty)
          'referenceNumber': _referenceController.text.trim(),
        if (_notesController.text.trim().isNotEmpty)
          'notes': _notesController.text.trim(),
      });

      // Invalidate invoice detail so it refreshes
      ref.invalidate(invoiceDetailProvider(widget.invoiceId));
      ref.invalidate(invoiceListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record payment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoiceAsync = ref.watch(invoiceDetailProvider(widget.invoiceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Payment'),
      ),
      body: invoiceAsync.when(
        loading: () => const KLoading(message: 'Loading invoice...'),
        error: (err, _) => KErrorView(
          message: 'Failed to load invoice',
          onRetry: () =>
              ref.invalidate(invoiceDetailProvider(widget.invoiceId)),
        ),
        data: (data) {
          final invoice = (data['data'] ?? data) as Map<String, dynamic>;
          final invoiceNumber =
              invoice['invoiceNumber'] as String? ?? '--';
          final total =
              (invoice['total'] as num?)?.toDouble() ?? 0;
          final balanceDue =
              (invoice['balanceDue'] as num?)?.toDouble() ?? total;
          final customerName =
              invoice['contactName'] as String? ?? 'Customer';

          // Pre-fill amount with balance due
          if (_amountController.text.isEmpty) {
            _amountController.text = balanceDue.toStringAsFixed(2);
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: KSpacing.pagePadding,
              children: [
                // ── Invoice Summary ──
                KCard(
                  borderColor: KColors.primary.withValues(alpha: 0.3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invoice', style: KTypography.bodySmall),
                      KSpacing.vGapXs,
                      Text(invoiceNumber, style: KTypography.h3),
                      KSpacing.vGapXs,
                      Text(customerName, style: KTypography.bodyMedium),
                      KSpacing.vGapMd,
                      Row(
                        children: [
                          _InfoChip(
                            label: 'Total',
                            value: CurrencyFormatter.formatIndian(total),
                          ),
                          KSpacing.hGapMd,
                          _InfoChip(
                            label: 'Balance Due',
                            value:
                                CurrencyFormatter.formatIndian(balanceDue),
                            color: KColors.error,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                KSpacing.vGapLg,

                // ── Amount ──
                KTextField.amount(
                  label: 'Payment Amount',
                  controller: _amountController,
                  validator: (v) {
                    final val = double.tryParse(v ?? '');
                    if (val == null || val <= 0) {
                      return 'Enter a valid amount';
                    }
                    if (val > balanceDue) {
                      return 'Amount exceeds balance due';
                    }
                    return null;
                  },
                ),
                KSpacing.vGapMd,

                // ── Payment Method ──
                Text('Payment Method', style: KTypography.labelLarge),
                KSpacing.vGapSm,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _paymentMethods.map((m) {
                    final isSelected = _paymentMethod == m.$1;
                    return ChoiceChip(
                      avatar: Icon(
                        m.$3,
                        size: 18,
                        color: isSelected
                            ? KColors.primary
                            : KColors.textSecondary,
                      ),
                      label: Text(m.$2),
                      selected: isSelected,
                      selectedColor:
                          KColors.primary.withValues(alpha: 0.12),
                      onSelected: (_) =>
                          setState(() => _paymentMethod = m.$1),
                    );
                  }).toList(),
                ),
                KSpacing.vGapMd,

                // ── Date ──
                KTextField(
                  label: 'Payment Date',
                  controller: TextEditingController(
                    text: DateFormatter.display(_paymentDate),
                  ),
                  readOnly: true,
                  prefixIcon: Icons.calendar_today,
                  onTap: _pickDate,
                ),
                KSpacing.vGapMd,

                // ── Reference Number ──
                KTextField(
                  label: 'Reference / Transaction Number',
                  hint: 'e.g., UTR, cheque number',
                  controller: _referenceController,
                  prefixIcon: Icons.tag,
                ),
                KSpacing.vGapMd,

                // ── Notes ──
                KTextField(
                  label: 'Notes',
                  hint: 'Optional',
                  controller: _notesController,
                  maxLines: 3,
                ),
                KSpacing.vGapLg,

                // ── Submit ──
                KButton(
                  label: 'Record Payment',
                  icon: Icons.check,
                  fullWidth: true,
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _submit,
                ),
                KSpacing.vGapXl,
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _InfoChip({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: KTypography.bodySmall),
        Text(
          value,
          style: KTypography.amountSmall.copyWith(
            color: color ?? KColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
