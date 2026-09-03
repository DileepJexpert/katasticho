import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/date_formatter.dart';
import '../data/vendor_payment_dto.dart';
import '../data/vendor_payment_providers.dart';
import '../data/vendor_payment_repository.dart';

class VendorPaymentDetailScreen extends ConsumerWidget {
  final String paymentId;

  const VendorPaymentDetailScreen({super.key, required this.paymentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentAsync = ref.watch(vendorPaymentDetailProvider(paymentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Details'),
        actions: [
          paymentAsync.whenOrNull(
                data: (data) {
                  return PopupMenuButton<String>(
                    onSelected: (value) =>
                        _handleAction(context, ref, value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'cheque_print',
                        child: Row(
                          children: [
                            Icon(Icons.print_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Print Cheque Leaf'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'void',
                        child: Row(
                          children: [
                            Icon(Icons.block_outlined, size: 18, color: KColors.error),
                            SizedBox(width: 8),
                            Text('Void Payment',
                                style: TextStyle(color: KColors.error)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: paymentAsync.when(
        loading: () => const KLoading(message: 'Loading payment...'),
        error: (err, _) => KErrorView(
          message: 'Failed to load payment',
          onRetry: () =>
              ref.invalidate(vendorPaymentDetailProvider(paymentId)),
        ),
        data: (data) {
          final raw = (data['data'] ?? data) as Map<String, dynamic>;
          final p = VendorPaymentDto(raw);
          return _PaymentDetailBody(payment: p);
        },
      ),
    );
  }

  void _handleAction(
      BuildContext context, WidgetRef ref, String action) {
    if (action == 'void') {
      _showVoidConfirmation(context, ref);
    } else if (action == 'cheque_print') {
      _showChequePrintDialog(context, ref);
    }
  }

  void _showChequePrintDialog(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final repo = ref.read(vendorPaymentRepositoryProvider);
      final chequeData = await repo.getChequePrint(paymentId);
      if (!context.mounted) return;
      Navigator.pop(context); // close loader

      showDialog(
        context: context,
        builder: (ctx) => _ChequeLeafPreviewDialog(data: chequeData),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // close loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load cheque data: $e'), backgroundColor: KColors.error),
      );
    }
  }

  void _showVoidConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void Payment?'),
        content: const Text(
          'This will reverse the journal entry and restore bill balances. '
          'This action cannot be undone.',
        ),
        actions: [
          KButton.outlined(
            label: 'Keep',
            onPressed: () => Navigator.pop(ctx),
          ),
          KSpacing.hGapSm,
          KButton.danger(
            label: 'Void Payment',
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final repo = ref.read(vendorPaymentRepositoryProvider);
                await repo.voidPayment(paymentId);
                ref.invalidate(vendorPaymentDetailProvider(paymentId));
                ref.invalidate(vendorPaymentListProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Payment voided — journal reversed')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Failed to void payment')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class _PaymentDetailBody extends StatelessWidget {
  final VendorPaymentDto payment;

  const _PaymentDetailBody({required this.payment});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(KSpacing.md),
            color: KColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.paymentNumber, style: KTypography.mono(fontSize: 20, fontWeight: FontWeight.w700)),
                KSpacing.vGapSm,
                Text(payment.vendorName, style: KTypography.bodyLarge),
                KSpacing.vGapMd,
                KMoney(
                  payment.amount,
                  size: KMoneySize.large,
                  style: const TextStyle(
                    color: KColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          const TabBar(
            tabs: [
              Tab(text: 'Details'),
              Tab(text: 'Allocations'),
            ],
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              children: [
                // Details tab
                SingleChildScrollView(
                  padding: KSpacing.pagePadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      KCard(
                        child: Column(
                          children: [
                            KDetailRow(
                              label: 'Payment #',
                              valueWidget: Text(
                                payment.paymentNumber,
                                style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            KDetailRow(
                              label: 'Vendor',
                              value: payment.vendorName,
                            ),
                            KDetailRow(
                              label: 'Payment Date',
                              value: payment.paymentDate.isNotEmpty
                                  ? DateFormatter.display(
                                      DateTime.parse(payment.paymentDate))
                                  : '--',
                            ),
                            KDetailRow(
                              label: 'Mode',
                              value: payment.paymentModeLabel,
                            ),
                            if (payment.referenceNumber.isNotEmpty)
                              KDetailRow(
                                  label: 'Reference #',
                                  valueWidget: Text(
                                    payment.referenceNumber,
                                    style: KTypography.mono(fontSize: 13),
                                  )),
                            KDetailRow(
                              label: 'Currency',
                              value: payment.currency,
                            ),
                            const Divider(),
                            KDetailRow(
                              label: 'Amount',
                              valueWidget: KMoney(
                                payment.amount,
                                size: KMoneySize.medium,
                                style: const TextStyle(
                                  color: KColors.success,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (payment.tdsAmount > 0)
                              KDetailRow(
                                label: 'TDS Deducted',
                                valueWidget: KMoney(
                                  payment.tdsAmount,
                                  size: KMoneySize.small,
                                  style: const TextStyle(
                                    color: KColors.warning,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (payment.notes.isNotEmpty) ...[
                              const Divider(),
                              KDetailRow(
                                  label: 'Notes', value: payment.notes),
                            ],
                          ],
                        ),
                      ),
                      KSpacing.vGapMd,
                      KCustomFieldsCard(entityType: 'VENDOR_PAYMENT', entityId: payment.id),
                    ],
                  ),
                ),

                // Allocations tab — which bills this payment was applied to
                _AllocationsTab(allocations: payment.allocations),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AllocationsTab extends StatelessWidget {
  final List<PaymentAllocationDto> allocations;

  const _AllocationsTab({required this.allocations});

  @override
  Widget build(BuildContext context) {
    if (allocations.isEmpty) {
      return const KEmptyState(
        icon: Icons.receipt_outlined,
        title: 'No allocations',
        subtitle: 'This payment has not been allocated to any bills',
      );
    }

    return ListView.builder(
      padding: KSpacing.pagePadding,
      itemCount: allocations.length,
      itemBuilder: (context, index) {
        final alloc = allocations[index];
        return KCard(
          margin: const EdgeInsets.only(bottom: KSpacing.sm),
          onTap: () {
            if (alloc.billId.isNotEmpty) {
              context.go('/bills/${alloc.billId}');
            }
          },
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: KColors.primary.withValues(alpha: 0.1),
                  borderRadius: KSpacing.borderRadiusMd,
                ),
                child: const Icon(
                  Icons.receipt_outlined,
                  color: KColors.primary,
                  size: 20,
                ),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alloc.billNumber,
                      style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Tap to view bill',
                      style: KTypography.bodySmall.copyWith(
                        color: KColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              KMoney(
                alloc.amountApplied,
                size: KMoneySize.small,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              KSpacing.hGapSm,
              const Icon(Icons.chevron_right, color: KColors.textHint),
            ],
          ),
        );
      },
    );
  }
}

class _ChequeLeafPreviewDialog extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ChequeLeafPreviewDialog({required this.data});

  @override
  Widget build(BuildContext context) {
    final payee = data['payeeName']?.toString() ?? '';
    final amountFormatted = data['amountFormatted']?.toString() ?? '';
    final amountInWords = data['amountInWords']?.toString() ?? '';
    final dateSpaced = data['dateSpaced']?.toString() ?? '';
    final chqNo = data['chequeNumber']?.toString() ?? '';
    final bankAcc = data['bankAccountNo']?.toString() ?? '';
    final ifsc = data['ifscCode']?.toString() ?? '';
    final bankName = data['bankName']?.toString() ?? '';
    final orgName = data['organisationName']?.toString() ?? 'Organisation';

    final dateChars = dateSpaced.split(' ').where((s) => s.isNotEmpty).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: KSpacing.borderRadiusLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_outlined, color: KColors.primary),
                  KSpacing.hGapSm,
                  Text('Cheque Leaf Preview (CTS-2010)', style: KTypography.h3),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              KSpacing.vGapMd,

              // ── Cheque Leaf Container ──
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCFAF2),
                  borderRadius: KSpacing.borderRadiusMd,
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top row: Crossing on left + Bank Info in center + Date on right
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // A/C Payee Crossing
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF475569), width: 1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'A/C PAYEE ONLY',
                            style: KTypography.mono(fontSize: 10, fontWeight: FontWeight.w700)
                                .copyWith(letterSpacing: 1),
                          ),
                        ),
                        const Spacer(),
                        // Date boxes
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('DATE', style: KTypography.labelSmall.copyWith(fontSize: 9)),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: dateChars.map((char) {
                                return Container(
                                  width: 18,
                                  height: 22,
                                  margin: const EdgeInsetsDirectional.only(start: 2),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFF64748B), width: 1),
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Text(
                                    char,
                                    style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Payee Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Pay', style: KTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.only(bottom: 2),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Color(0xFF94A3B8), width: 1)),
                            ),
                            child: Text(
                              payee,
                              style: KTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Or Bearer', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Rupees in words + Amount Box
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Rupees', style: KTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      decoration: const BoxDecoration(
                                        border: Border(bottom: BorderSide(color: Color(0xFF94A3B8), width: 1)),
                                      ),
                                      child: Text(
                                        amountInWords,
                                        style: KTypography.bodySmall.copyWith(
                                          fontWeight: FontWeight.w600,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Amount Box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF334155), width: 1.5),
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.white,
                          ),
                          child: Text(
                            amountFormatted,
                            style: KTypography.mono(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ).copyWith(color: const Color(0xFF0F172A)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Bottom Row: Bank & Account Details + Signature Box
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (bankAcc.isNotEmpty)
                              Text('A/C No: $bankAcc', style: KTypography.mono(fontSize: 11, fontWeight: FontWeight.w600)),
                            if (ifsc.isNotEmpty)
                              Text('IFSC: $ifsc  ${bankName.isNotEmpty ? "($bankName)" : ""}',
                                  style: KTypography.mono(fontSize: 10, fontWeight: FontWeight.w500)),
                            if (chqNo.isNotEmpty)
                              Text('Cheque Ref: $chqNo',
                                  style: KTypography.mono(fontSize: 10, color: KColors.textSecondary)),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('For $orgName', style: KTypography.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 24),
                            Text('Authorised Signatory', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              KSpacing.vGapLg,

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  KButton.outlined(
                    label: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                  KSpacing.hGapSm,
                  KButton.primary(
                    label: 'Print Cheque',
                    icon: Icons.print,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sending to printer layout...')),
                      );
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
