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
import '../data/credit_reminder_repository.dart';

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
    final invoices =
        (contact['invoices'] as List?)?.cast<Map<String, dynamic>>() ?? [];

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
                  style: KTypography.amountLarge.copyWith(color: KColors.error),
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
                      final invId = inv['invoiceId']?.toString();
                      return _InvoiceRow(
                        invoice: inv,
                        onTap: () {
                          if (invId != null) context.push('/invoices/$invId');
                        },
                        onRecordPayment: () {
                          if (invId != null) {
                            context.push('/invoices/$invId/pay');
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
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openFollowUpSheet(context, ref),
                  icon: const Icon(Icons.event_note_outlined, size: 18),
                  label: const Text('Follow-up'),
                ),
              ),
              KSpacing.hGapSm,
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      _sendWhatsAppReminder(context, ref, name, total, phone),
                  icon: const Icon(Icons.message, size: 18),
                  label: const Text('WhatsApp'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFollowUpSheet(BuildContext context, WidgetRef ref) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CollectionFollowUpSheet(contactId: contactId, ref: ref),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collection follow-up saved')),
      );
    }
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
    final message =
        'Dear $firstName, this is a reminder that your outstanding amount is $formattedAmount. '
        'Please make the payment at your earliest convenience. - $orgName';

    String phoneNumber = phone ?? '';
    if (phoneNumber.isEmpty && context.mounted) {
      phoneNumber = await _promptForPhone(context) ?? '';
    }
    if (phoneNumber.isEmpty) return;

    phoneNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\+]'), '');
    if (phoneNumber.length == 10) phoneNumber = '91$phoneNumber';

    final url = Uri.parse(
      'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}',
    );
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
  final VoidCallback onRecordPayment;

  const _InvoiceRow({
    required this.invoice,
    required this.onTap,
    required this.onRecordPayment,
  });

  @override
  Widget build(BuildContext context) {
    final number = invoice['invoiceNumber'] as String? ?? '--';
    final balanceDue = (invoice['balanceDue'] as num?)?.toDouble() ?? 0;
    final totalAmount =
        (invoice['totalAmount'] as num?)?.toDouble() ?? balanceDue;
    final daysOverdue = (invoice['daysOverdue'] as num?)?.toInt() ?? 0;
    final invoiceDate = invoice['invoiceDate'] as String?;
    final bucket = invoice['bucket'] as String? ?? '';
    final dateDisplay = invoiceDate != null && invoiceDate.length >= 10
        ? _formatDate(invoiceDate)
        : '--';

    return KCard(
      onTap: onTap,
      child: Column(
        children: [
          Row(
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
                          const Text(' · ',
                              style: TextStyle(color: KColors.textHint)),
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
                  Text(
                    daysOverdue > 0 ? '$daysOverdue days' : 'Not due',
                    style: KTypography.labelSmall.copyWith(
                      color: daysOverdue > 0
                          ? _bucketColor(bucket)
                          : KColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
          KSpacing.vGapSm,
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRecordPayment,
              icon: const Icon(Icons.payments_outlined, size: 16),
              label: const Text('Record payment'),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
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
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${d.day}-${months[d.month]}';
    } catch (_) {
      return isoDate;
    }
  }
}

class _CollectionFollowUpSheet extends StatefulWidget {
  final String contactId;
  final WidgetRef ref;

  const _CollectionFollowUpSheet({
    required this.contactId,
    required this.ref,
  });

  @override
  State<_CollectionFollowUpSheet> createState() =>
      _CollectionFollowUpSheetState();
}

class _CollectionFollowUpSheetState extends State<_CollectionFollowUpSheet> {
  final _noteController = TextEditingController();
  String _status = 'TO_CALL';
  DateTime? _promiseDate;
  bool _saving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.ref.read(creditReminderRepositoryProvider).recordFollowUp(
        widget.contactId,
        {
          'status': _status,
          if (_promiseDate != null)
            'promiseToPayDate': _formatApiDate(_promiseDate!),
          if (_noteController.text.trim().isNotEmpty)
            'note': _noteController.text.trim(),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save follow-up')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickPromiseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _promiseDate ?? DateTime.now().add(const Duration(days: 3)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _promiseDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        KSpacing.md,
        KSpacing.md,
        KSpacing.md,
        KSpacing.md + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Collection Follow-up', style: KTypography.h3),
          KSpacing.vGapMd,
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'TO_CALL', child: Text('To call')),
              DropdownMenuItem(value: 'VISITED', child: Text('Visited')),
              DropdownMenuItem(value: 'PROMISED', child: Text('Promised')),
              DropdownMenuItem(value: 'DISPUTED', child: Text('Disputed')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _status = value);
            },
          ),
          KSpacing.vGapSm,
          OutlinedButton.icon(
            onPressed: _pickPromiseDate,
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text(_promiseDate == null
                ? 'Promise-to-pay date'
                : 'PTP ${_formatDisplayDate(_promiseDate!)}'),
          ),
          KSpacing.vGapSm,
          KTextField(
            label: 'Note',
            controller: _noteController,
            maxLines: 3,
          ),
          KSpacing.vGapLg,
          KButton(
            label: _saving ? 'Saving...' : 'Save Follow-up',
            icon: Icons.save_outlined,
            fullWidth: true,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  String _formatApiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatDisplayDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
