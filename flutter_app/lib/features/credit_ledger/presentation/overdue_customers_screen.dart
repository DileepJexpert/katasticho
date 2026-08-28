import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/credit_reminder_repository.dart';

class OverdueCustomersScreen extends ConsumerStatefulWidget {
  const OverdueCustomersScreen({super.key});

  @override
  ConsumerState<OverdueCustomersScreen> createState() =>
      _OverdueCustomersScreenState();
}

class _OverdueCustomersScreenState
    extends ConsumerState<OverdueCustomersScreen> {
  List<Map<String, dynamic>>? _customers;
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(creditReminderRepositoryProvider);
      final response = await repo.getOverdueCustomers();
      final raw = response['data'];
      final dataList = raw is List ? raw : <dynamic>[];
      setState(() {
        _customers = dataList.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      setState(() => _error = 'Failed to load overdue customers');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getFilteredCustomers() {
    if (_customers == null) return [];
    var filtered = _customers!;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((c) {
        final name = (c['contactName'] as String? ?? '').toLowerCase();
        final phone = (c['phone'] as String? ?? '').toLowerCase();
        return name.contains(q) || phone.contains(q);
      }).toList();
    }
    return filtered;
  }

  double _totalOverdue() {
    if (_customers == null) return 0;
    double total = 0;
    for (final c in _customers!) {
      total += (c['overdueAmount'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Overdue Reminders',
            searchHint: 'Search customer or phone...',
            onSearchChanged: (q) => setState(() => _searchQuery = q.trim()),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const KShimmerList();
    }
    if (_error != null) {
      return KErrorView(message: _error!, onRetry: _loadData);
    }
    if (_customers == null) {
      return const KEmptyState(
        icon: Icons.notifications_none_outlined,
        title: 'No data',
      );
    }

    final customers = _getFilteredCustomers();
    final totalOverdue = _totalOverdue();
    final customerCount = _customers!.length;

    if (customers.isEmpty && _searchQuery.isEmpty) {
      return const KEmptyState(
        icon: Icons.celebration_outlined,
        title: 'No overdue balances',
        subtitle: 'All customers are up to date with their payments',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: KSpacing.pagePadding,
        itemCount: customers.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: KSpacing.md),
              child: _SummaryCard(
                totalOverdue: totalOverdue,
                customerCount: customerCount,
              ),
            );
          }
          final customer = customers[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: KSpacing.sm),
            child: _OverdueCustomerCard(
              customer: customer,
              onSendReminder: () => _sendReminder(customer),
              onViewDetails: () {
                final contactId = customer['contactId']?.toString() ?? '';
                context.push('/credit-ledger/$contactId', extra: {
                  'contactId': contactId,
                  'contactName': customer['contactName'],
                  'phone': customer['phone'],
                  'totalOutstanding': customer['totalOutstanding'],
                  'invoices': customer['invoices'],
                });
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _sendReminder(Map<String, dynamic> customer) async {
    final contactId = customer['contactId']?.toString() ?? '';
    if (contactId.isEmpty) return;

    try {
      final repo = ref.read(creditReminderRepositoryProvider);
      final response = await repo.getReminderText(contactId);
      final data = response['data'] is Map
          ? response['data'] as Map<String, dynamic>
          : response;

      final message = data['message']?.toString() ?? '';
      String phone = data['phone']?.toString() ?? '';

      if (!mounted) return;

      // Show bottom sheet with options
      final action = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => _ReminderActionSheet(
          customerName: customer['contactName'] as String? ?? 'Customer',
          message: message,
          hasPhone: phone.isNotEmpty,
        ),
      );

      if (action == null || !mounted) return;

      if (action == 'whatsapp') {
        if (phone.isEmpty) {
          phone = await _promptForPhone() ?? '';
          if (phone.isEmpty) return;
        }
        // Clean phone number
        phone = phone.replaceAll(RegExp(r'[\s\-\+]'), '');
        if (phone.length == 10) phone = '91$phone';

        final url = Uri.parse(
            'https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          // Mark reminder as sent
          await repo.markReminderSent(contactId, channel: 'WHATSAPP');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reminder sent via WhatsApp')),
            );
            _loadData(); // Refresh to update last sent timestamp
          }
        }
      } else if (action == 'copy') {
        await Clipboard.setData(ClipboardData(text: message));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reminder message copied to clipboard')),
          );
        }
      } else if (action == 'sms') {
        if (phone.isEmpty) {
          phone = await _promptForPhone() ?? '';
          if (phone.isEmpty) return;
        }
        phone = phone.replaceAll(RegExp(r'[\s\-\+]'), '');
        if (phone.length == 10) phone = '91$phone';

        final smsUrl = Uri.parse('sms:+$phone?body=${Uri.encodeComponent(message)}');
        if (await canLaunchUrl(smsUrl)) {
          await launchUrl(smsUrl);
          await repo.markReminderSent(contactId, channel: 'SMS');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Opening SMS app...')),
            );
            _loadData();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate reminder: $e')),
        );
      }
    }
  }

  Future<String?> _promptForPhone() {
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
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ── Summary Card ──────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double totalOverdue;
  final int customerCount;

  const _SummaryCard({
    required this.totalOverdue,
    required this.customerCount,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Overdue', style: KTypography.bodySmall),
                KSpacing.vGapXs,
                KMoney(
                  totalOverdue,
                  size: KMoneySize.large,
                  style: const TextStyle(color: KColors.error, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: KColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(KSpacing.radiusSm),
            ),
            child: Column(
              children: [
                Text(
                  '$customerCount',
                  style: KTypography.h2.copyWith(color: KColors.error),
                ),
                Text('overdue', style: KTypography.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Overdue Customer Card ─────────────────────────────────────────────

class _OverdueCustomerCard extends StatelessWidget {
  final Map<String, dynamic> customer;
  final VoidCallback onSendReminder;
  final VoidCallback onViewDetails;

  const _OverdueCustomerCard({
    required this.customer,
    required this.onSendReminder,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final name = customer['contactName'] as String? ?? 'Unknown';
    final phone = customer['phone'] as String? ?? '';
    final totalOutstanding =
        (customer['totalOutstanding'] as num?)?.toDouble() ?? 0;
    final maxDaysOverdue =
        (customer['maxDaysOverdue'] as num?)?.toInt() ?? 0;
    final invoiceCount = (customer['invoiceCount'] as num?)?.toInt() ?? 0;
    final lastReminderSentAt = customer['lastReminderSentAt'] as String?;

    final severityColor = _getSeverityColor(maxDaysOverdue);

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer info row
          InkWell(
            onTap: onViewDetails,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: severityColor.withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: KTypography.labelLarge.copyWith(color: severityColor),
                  ),
                ),
                KSpacing.hGapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: KTypography.labelLarge),
                      KSpacing.vGapXs,
                      Row(
                        children: [
                          if (phone.isNotEmpty) ...[
                            Icon(Icons.phone, size: 12, color: KColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(phone, style: KTypography.bodySmall),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: severityColor.withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(KSpacing.radiusXs),
                            ),
                            child: Text(
                              '$maxDaysOverdue days overdue',
                              style: KTypography.labelSmall.copyWith(
                                color: severityColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    KMoney(
                      totalOutstanding,
                      size: KMoneySize.small,
                      style: TextStyle(
                        color: severityColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    KSpacing.vGapXs,
                    Text(
                      '$invoiceCount invoice${invoiceCount == 1 ? '' : 's'}',
                      style: KTypography.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),

          KSpacing.vGapSm,
          const Divider(height: 1),
          KSpacing.vGapSm,

          // Action row
          Row(
            children: [
              if (lastReminderSentAt != null) ...[
                Icon(Icons.schedule, size: 14, color: KColors.textHint),
                const SizedBox(width: 4),
                Text(
                  'Last: ${_formatTimestamp(lastReminderSentAt)}',
                  style: KTypography.labelSmall.copyWith(
                    color: KColors.textHint,
                  ),
                ),
              ],
              const Spacer(),
              TextButton.icon(
                onPressed: onViewDetails,
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Details'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onSendReminder,
                icon: const Icon(Icons.message, size: 16),
                label: const Text('Send Reminder'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(int daysOverdue) {
    if (daysOverdue > 90) return KColors.error;
    if (daysOverdue > 30) return KColors.warning;
    if (daysOverdue > 7) return const Color(0xFFF59E0B); // amber
    return KColors.textSecondary;
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      return '${diff.inMinutes}m ago';
    } catch (_) {
      return timestamp;
    }
  }
}

// ── Reminder Action Bottom Sheet ──────────────────────────────────────

class _ReminderActionSheet extends StatelessWidget {
  final String customerName;
  final String message;
  final bool hasPhone;

  const _ReminderActionSheet({
    required this.customerName,
    required this.message,
    required this.hasPhone,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send Reminder to $customerName',
              style: KTypography.h3,
            ),
            KSpacing.vGapMd,

            // Message preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: KColors.surface,
                borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                border: Border.all(color: KColors.divider),
              ),
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Text(message, style: KTypography.bodySmall),
              ),
            ),

            KSpacing.vGapLg,

            // Actions
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.message, color: Color(0xFF25D366), size: 20),
              ),
              title: const Text('Send via WhatsApp'),
              subtitle: hasPhone
                  ? const Text('Opens WhatsApp with message')
                  : const Text('You will be asked for phone number'),
              onTap: () => Navigator.pop(context, 'whatsapp'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: KColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.sms_outlined, color: KColors.primary, size: 20),
              ),
              title: const Text('Send via SMS'),
              subtitle: const Text('Opens SMS app with message'),
              onTap: () => Navigator.pop(context, 'sms'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: KColors.textSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.copy_outlined,
                    color: KColors.textSecondary, size: 20),
              ),
              title: const Text('Copy to clipboard'),
              subtitle: const Text('Copy message text'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
          ],
        ),
      ),
    );
  }
}
