import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../reports/data/report_repository.dart';

class ContactStatementScreen extends ConsumerStatefulWidget {
  final String contactId;
  final String? contactName;

  const ContactStatementScreen({
    super.key,
    required this.contactId,
    this.contactName,
  });

  @override
  ConsumerState<ContactStatementScreen> createState() =>
      _ContactStatementScreenState();
}

class _ContactStatementScreenState
    extends ConsumerState<ContactStatementScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  Map<String, dynamic>? _ledger;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, 1, 1);
    _endDate = now;
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(reportRepositoryProvider);
      final data = await repo.getContactLedger(
        contactId: widget.contactId,
        startDate: DateFormatter.api(_startDate),
        endDate: DateFormatter.api(_endDate),
      );
      setState(() => _ledger = (data['data'] ?? data) as Map<String, dynamic>);
    } catch (e) {
      setState(() => _error = 'Failed to load statement');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _ledger?['contactName']?.toString() ?? widget.contactName ?? 'Statement';

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Column(
        children: [
          // Date range picker
          Padding(
            padding: const EdgeInsets.fromLTRB(
                KSpacing.md, KSpacing.sm, KSpacing.md, 0),
            child: Row(
              children: [
                Expanded(
                  child: KDatePicker(
                    label: 'From',
                    value: _startDate,
                    onChanged: (d) {
                      _startDate = d;
                      _loadLedger();
                    },
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: KDatePicker(
                    label: 'To',
                    value: _endDate,
                    onChanged: (d) {
                      _endDate = d;
                      _loadLedger();
                    },
                  ),
                ),
              ],
            ),
          ),
          KSpacing.vGapSm,

          if (_isLoading)
            const Expanded(child: KLoading())
          else if (_error != null)
            Expanded(
              child: Center(child: KErrorBanner(message: _error!)),
            )
          else if (_ledger != null)
            Expanded(child: _buildStatement()),
        ],
      ),
    );
  }

  Widget _buildStatement() {
    final openingBalance =
        (_ledger!['openingBalance'] as num?)?.toDouble() ?? 0;
    final closingBalance =
        (_ledger!['closingBalance'] as num?)?.toDouble() ?? 0;
    final totalInvoiced =
        (_ledger!['totalInvoiced'] as num?)?.toDouble() ?? 0;
    final totalPaid = (_ledger!['totalPaid'] as num?)?.toDouble() ?? 0;
    final entries = (_ledger!['entries'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final contactType = _ledger!['contactType']?.toString() ?? 'CUSTOMER';
    final isCustomer = contactType == 'CUSTOMER';

    return Column(
      children: [
        // Summary cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: isCustomer ? 'Invoiced' : 'Billed',
                  amount: totalInvoiced,
                  color: KColors.primary,
                ),
              ),
              KSpacing.hGapSm,
              Expanded(
                child: _SummaryCard(
                  label: 'Paid',
                  amount: totalPaid,
                  color: KColors.success,
                ),
              ),
              KSpacing.hGapSm,
              Expanded(
                child: _SummaryCard(
                  label: 'Balance',
                  amount: closingBalance,
                  color: closingBalance > 0 ? KColors.error : KColors.success,
                ),
              ),
            ],
          ),
        ),
        KSpacing.vGapSm,

        // Opening balance
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.md, vertical: 8),
          color: KColors.divider.withValues(alpha: 0.3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Opening Balance', style: KTypography.labelSmall),
              Text(CurrencyFormatter.formatIndian(openingBalance),
                  style: KTypography.amountSmall),
            ],
          ),
        ),

        // Entries list
        Expanded(
          child: entries.isEmpty
              ? const KEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No transactions',
                  subtitle: 'No entries found for this period',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.md, vertical: KSpacing.sm),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _EntryTile(entry: entries[index], isCustomer: isCustomer),
                ),
        ),

        // Closing balance
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(KSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Closing Balance', style: KTypography.labelLarge),
              Text(
                CurrencyFormatter.formatIndian(closingBalance),
                style: KTypography.amountMedium.copyWith(
                  color: closingBalance > 0 ? KColors.error : KColors.success,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: KTypography.labelSmall),
          KSpacing.vGapXs,
          Text(
            CurrencyFormatter.formatCompact(amount),
            style: KTypography.amountSmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final Map<String, dynamic> entry;
  final bool isCustomer;

  const _EntryTile({required this.entry, required this.isCustomer});

  @override
  Widget build(BuildContext context) {
    final date = entry['date']?.toString() ?? '';
    final type = entry['type']?.toString() ?? '';
    final number = entry['number']?.toString() ?? '';
    final description = entry['description']?.toString() ?? '';
    final debit = (entry['debit'] as num?)?.toDouble() ?? 0;
    final credit = (entry['credit'] as num?)?.toDouble() ?? 0;
    final running = (entry['runningBalance'] as num?)?.toDouble() ?? 0;

    final isPayment = type.contains('PAYMENT');
    final icon = isPayment ? Icons.payments_outlined : Icons.receipt_outlined;
    final iconColor = isPayment ? KColors.success : KColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: iconColor.withValues(alpha: 0.1),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          KSpacing.hGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(number, style: KTypography.labelMedium),
                    ),
                    if (debit > 0)
                      Text(
                        CurrencyFormatter.formatIndian(debit),
                        style: KTypography.amountSmall
                            .copyWith(color: KColors.error),
                      ),
                    if (credit > 0)
                      Text(
                        CurrencyFormatter.formatIndian(credit),
                        style: KTypography.amountSmall
                            .copyWith(color: KColors.success),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(date,
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textHint)),
                    const Spacer(),
                    Text(
                      'Bal: ${CurrencyFormatter.formatIndian(running)}',
                      style: KTypography.labelSmall
                          .copyWith(color: KColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
