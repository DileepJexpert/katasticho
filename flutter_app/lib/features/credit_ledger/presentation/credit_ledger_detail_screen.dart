import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';

class CreditLedgerDetailScreen extends ConsumerWidget {
  final String contactId;
  final Map<String, dynamic>? contactData;

  const CreditLedgerDetailScreen({
    super.key,
    required this.contactId,
    this.contactData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (contactData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customer Ledger')),
        body: const KErrorView(message: 'No data available'),
      );
    }

    final contact = contactData!;
    final name = contact['contactName'] as String? ?? 'Customer';
    final phone = contact['phone'] as String?;
    final total = (contact['totalOutstanding'] as num?)?.toDouble() ?? 0;
    final invoices = (contact['invoices'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 20),
            tooltip: 'View contact',
            onPressed: () => context.push('/contacts/$contactId'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(KSpacing.md),
            color: KColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Outstanding', style: KTypography.bodySmall),
                KSpacing.vGapXs,
                Text(
                  CurrencyFormatter.formatIndian(total),
                  style: KTypography.amountLarge.copyWith(
                    color: KColors.error,
                  ),
                ),
                KSpacing.vGapSm,
                Text(
                  '${invoices.length} unpaid invoice${invoices.length == 1 ? '' : 's'}',
                  style: KTypography.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Invoice list
          Expanded(
            child: invoices.isEmpty
                ? const KEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No outstanding invoices',
                  )
                : ListView.separated(
                    padding: KSpacing.pagePadding,
                    itemCount: invoices.length,
                    separatorBuilder: (_, __) => KSpacing.vGapSm,
                    itemBuilder: (context, index) {
                      final inv = invoices[index];
                      return _InvoiceRow(
                        invoice: inv,
                        onTap: () {
                          final invId = inv['invoiceId']?.toString();
                          if (invId != null) {
                            context.push('/invoices/$invId');
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
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
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _sendWhatsAppReminder(context, ref, name, total, phone),
              icon: const Icon(Icons.message, size: 20),
              label: const Text('Send Reminder via WhatsApp'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendWhatsAppReminder(
    BuildContext context,
    WidgetRef ref,
    String customerName,
    double amount,
    String? phone,
  ) async {
    final orgName = ref.read(authProvider).orgName ?? 'Our Store';
    final firstName = customerName.split(' ').first;
    final formattedAmount = CurrencyFormatter.formatIndian(amount);

    final message = 'Hi $firstName ji, $formattedAmount baaki hai. '
        'Jab ho sake payment kar dijiye. — $orgName';

    String phoneNumber = phone ?? '';
    if (phoneNumber.isEmpty && context.mounted) {
      phoneNumber = await _promptForPhone(context) ?? '';
    }
    if (phoneNumber.isEmpty) return;

    phoneNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\+]'), '');
    if (phoneNumber.length == 10) phoneNumber = '91$phoneNumber';

    final url = Uri.parse(
        'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
  }

  Future<String?> _promptForPhone(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Phone Number'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter phone number',
            prefixText: '+91 ',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onTap;

  const _InvoiceRow({required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final number = invoice['invoiceNumber'] as String? ?? '--';
    final balanceDue = (invoice['balanceDue'] as num?)?.toDouble() ?? 0;
    final totalAmount = (invoice['totalAmount'] as num?)?.toDouble() ?? balanceDue;
    final daysOverdue = (invoice['daysOverdue'] as num?)?.toInt() ?? 0;
    final invoiceDate = invoice['invoiceDate'] as String?;
    final bucket = invoice['bucket'] as String? ?? '';

    final dateDisplay = invoiceDate != null && invoiceDate.length >= 10
        ? _formatDate(invoiceDate)
        : '--';

    return KCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            color: _bucketColor(bucket),
            size: 22,
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(number, style: KTypography.labelLarge),
                KSpacing.vGapXs,
                Row(
                  children: [
                    Text(dateDisplay, style: KTypography.bodySmall),
                    if (totalAmount != balanceDue) ...[
                      const Text(' · ', style: TextStyle(color: KColors.textHint)),
                      Text(
                        'Total ${CurrencyFormatter.formatIndian(totalAmount)}',
                        style: KTypography.bodySmall,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.formatIndian(balanceDue),
                style: KTypography.amountSmall.copyWith(
                  color: _bucketColor(bucket),
                ),
              ),
              KSpacing.vGapXs,
              if (daysOverdue > 0)
                Text(
                  '$daysOverdue days',
                  style: KTypography.labelSmall.copyWith(
                    color: _bucketColor(bucket),
                  ),
                )
              else
                Text(
                  'Not due',
                  style: KTypography.labelSmall.copyWith(
                    color: KColors.success,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _bucketColor(String bucket) {
    return switch (bucket) {
      'CURRENT' => KColors.ageingCurrent,
      '1-30' => KColors.ageing1to30,
      '31-60' => KColors.ageing31to60,
      '61-90' => KColors.ageing61to90,
      '90+' => KColors.ageing90Plus,
      _ => KColors.warning,
    };
  }

  String _formatDate(String isoDate) {
    try {
      final d = DateTime.parse(isoDate);
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${d.day}-${months[d.month]}';
    } catch (_) {
      return isoDate;
    }
  }
}
