import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../data/report_repository.dart';

class GeneralLedgerScreen extends ConsumerStatefulWidget {
  const GeneralLedgerScreen({super.key});

  @override
  ConsumerState<GeneralLedgerScreen> createState() =>
      _GeneralLedgerScreenState();
}

class _GeneralLedgerScreenState extends ConsumerState<GeneralLedgerScreen> {
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  String _accountId = '';
  Map<String, dynamic>? _report;
  bool _isLoading = false;
  String? _error;

  Future<void> _loadReport() async {
    if (_accountId.isEmpty) {
      setState(() => _error = 'Please enter an account ID');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(reportRepositoryProvider);
      final data = await repo.getGeneralLedger(
        accountId: _accountId,
        startDate: DateFormatter.api(_startDate),
        endDate: DateFormatter.api(_endDate),
      );
      setState(() => _report = (data['data'] ?? data) as Map<String, dynamic>);
    } catch (e) {
      setState(() => _error = 'Failed to load general ledger');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('General Ledger')),
      body: Column(
        children: [
          Container(
            color: KColors.surface,
            padding: const EdgeInsets.all(KSpacing.md),
            child: Column(
              children: [
                KTextField(
                  label: 'Account',
                  hint: 'Select or search account',
                  prefixIcon: Icons.search,
                  onChanged: (v) => _accountId = v,
                ),
                KSpacing.vGapSm,
                Row(
                  children: [
                    Expanded(
                      child: KDatePicker(
                        label: 'From',
                        value: _startDate,
                        onChanged: (d) => _startDate = d,
                      ),
                    ),
                    KSpacing.hGapSm,
                    Expanded(
                      child: KDatePicker(
                        label: 'To',
                        value: _endDate,
                        onChanged: (d) => _endDate = d,
                      ),
                    ),
                    KSpacing.hGapSm,
                    KButton(
                      label: 'Go',
                      size: KButtonSize.small,
                      onPressed: _loadReport,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const KLoading(message: 'Loading ledger...')
                : _error != null
                    ? KErrorView(message: _error!, onRetry: _loadReport)
                    : _report == null
                        ? const KEmptyState(
                            icon: Icons.menu_book,
                            title: 'Select an account',
                            subtitle:
                                'Choose an account and date range to view the ledger',
                          )
                        : _buildReport(),
          ),
        ],
      ),
    );
  }

  Widget _buildReport() {
    final accountName = _report!['accountName'] as String? ?? '';
    final accountCode = _report!['accountCode'] as String? ?? '';
    final accountType = _report!['accountType'] as String? ?? '';
    final openingBalance =
        (_report!['openingBalance'] as num?)?.toDouble() ?? 0;
    final closingBalance =
        (_report!['closingBalance'] as num?)?.toDouble() ?? 0;
    final totalDebit = (_report!['totalDebit'] as num?)?.toDouble() ?? 0;
    final totalCredit = (_report!['totalCredit'] as num?)?.toDouble() ?? 0;
    final entries = (_report!['entries'] as List?) ?? [];

    return SingleChildScrollView(
      padding: KSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Account header
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('$accountCode — $accountName',
                        style: KTypography.h3),
                    KSpacing.hGapSm,
                    KStatusChip(status: accountType, label: accountType),
                  ],
                ),
                KSpacing.vGapMd,
                Row(
                  children: [
                    _BalanceChip(
                      label: 'Opening',
                      amount: openingBalance,
                    ),
                    KSpacing.hGapMd,
                    _BalanceChip(
                      label: 'Closing',
                      amount: closingBalance,
                    ),
                  ],
                ),
              ],
            ),
          ),
          KSpacing.vGapMd,

          // Transactions
          Text('Transactions (${entries.length})', style: KTypography.h3),
          KSpacing.vGapSm,

          if (entries.isEmpty)
            const KEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No transactions',
            )
          else
            KDataTable(
              columns: const [
                KTableColumn(label: 'Date'),
                KTableColumn(label: 'Description'),
                KTableColumn(label: 'Debit', numeric: true),
                KTableColumn(label: 'Credit', numeric: true),
                KTableColumn(label: 'Balance', numeric: true),
              ],
              rows: entries.map((entry) {
                final e = entry as Map<String, dynamic>;
                return [
                  Text(e['effectiveDate'] as String? ?? '',
                      style: KTypography.bodySmall),
                  SizedBox(
                    width: 200,
                    child: Text(
                      e['description'] as String? ?? '',
                      style: KTypography.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatIndian(
                        (e['debit'] as num?)?.toDouble() ?? 0),
                    style: KTypography.amountSmall,
                  ),
                  Text(
                    CurrencyFormatter.formatIndian(
                        (e['credit'] as num?)?.toDouble() ?? 0),
                    style: KTypography.amountSmall,
                  ),
                  Text(
                    CurrencyFormatter.formatIndian(
                        (e['runningBalance'] as num?)?.toDouble() ?? 0),
                    style: KTypography.amountSmall
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ];
              }).toList(),
            ),

          KSpacing.vGapMd,

          // Totals
          KCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('Total Debit', style: KTypography.bodySmall),
                    Text(
                      CurrencyFormatter.formatIndian(totalDebit),
                      style: KTypography.amountMedium,
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text('Total Credit', style: KTypography.bodySmall),
                    Text(
                      CurrencyFormatter.formatIndian(totalCredit),
                      style: KTypography.amountMedium,
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

class _BalanceChip extends StatelessWidget {
  final String label;
  final double amount;

  const _BalanceChip({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: KTypography.labelSmall),
        Text(
          CurrencyFormatter.formatIndian(amount),
          style: KTypography.amountSmall,
        ),
      ],
    );
  }
}
