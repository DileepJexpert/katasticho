import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/date_formatter.dart';
import '../data/report_repository.dart';

class BalanceSheetScreen extends ConsumerStatefulWidget {
  const BalanceSheetScreen({super.key});

  @override
  ConsumerState<BalanceSheetScreen> createState() => _BalanceSheetScreenState();
}

class _BalanceSheetScreenState extends ConsumerState<BalanceSheetScreen> {
  DateTime _asOfDate = DateTime.now();
  Map<String, dynamic>? _report;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(reportRepositoryProvider);
      final data = await repo.getBalanceSheet(
        asOfDate: DateFormatter.api(_asOfDate),
      );
      setState(() => _report = (data['data'] ?? data) as Map<String, dynamic>);
    } catch (e) {
      setState(() => _error = 'Failed to load balance sheet');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Balance Sheet')),
      body: Column(
        children: [
          Container(
            color: KColors.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.md,
              vertical: KSpacing.sm,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < KSpacing.mobileBreakpoint;
                return Wrap(
                  spacing: KSpacing.md,
                  runSpacing: KSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: narrow ? constraints.maxWidth : 320,
                      child: KDatePicker(
                        label: 'As of Date',
                        value: _asOfDate,
                        onChanged: (d) {
                          _asOfDate = d;
                          _loadReport();
                        },
                      ),
                    ),
                    KButton(
                      label: 'Generate',
                      icon: Icons.refresh,
                      size: KButtonSize.small,
                      onPressed: _loadReport,
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const KLoading(message: 'Generating balance sheet...')
                : _error != null
                    ? KErrorView(message: _error!, onRetry: _loadReport)
                    : _report == null
                        ? const KEmptyState(
                            icon: Icons.account_balance,
                            title: 'No data available',
                          )
                        : _buildReport(),
          ),
        ],
      ),
    );
  }

  Widget _buildReport() {
    final totalAssets = (_report!['totalAssets'] as num?)?.toDouble() ?? 0;
    final totalLiabilities =
        (_report!['totalLiabilities'] as num?)?.toDouble() ?? 0;
    final totalEquity = (_report!['totalEquity'] as num?)?.toDouble() ?? 0;
    final retainedEarnings =
        (_report!['retainedEarnings'] as num?)?.toDouble() ?? 0;
    final isBalanced = _report!['isBalanced'] as bool? ?? false;
    final assetAccounts = (_report!['assetAccounts'] as List?) ?? [];
    final liabilityAccounts = (_report!['liabilityAccounts'] as List?) ?? [];
    final equityAccounts = (_report!['equityAccounts'] as List?) ?? [];

    return SingleChildScrollView(
      padding: KSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isBalanced ? KColors.successLight : KColors.errorLight,
              borderRadius: KSpacing.borderRadiusMd,
            ),
            child: Row(
              children: [
                Icon(
                  isBalanced ? Icons.check_circle : Icons.warning,
                  color: isBalanced ? KColors.success : KColors.error,
                  size: 20,
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: Text(
                    isBalanced
                        ? 'Assets = Liabilities + Equity'
                        : 'Balance sheet is NOT balanced!',
                    style: KTypography.labelLarge.copyWith(
                      color: isBalanced ? KColors.success : KColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
          KSpacing.vGapSm,

          // Assets
          _SectionCard(
            title: 'Assets',
            total: totalAssets,
            color: KColors.primary,
            accounts: assetAccounts,
          ),
          KSpacing.vGapSm,

          // Liabilities
          _SectionCard(
            title: 'Liabilities',
            total: totalLiabilities,
            color: KColors.warning,
            accounts: liabilityAccounts,
          ),
          KSpacing.vGapSm,

          // Equity
          _SectionCard(
            title: 'Equity',
            total: totalEquity,
            color: KColors.secondary,
            accounts: equityAccounts,
            footer: retainedEarnings != 0
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Retained Earnings',
                          style: KTypography.bodyMedium.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        KMoney(retainedEarnings, size: KMoneySize.small),
                      ],
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final double total;
  final Color color;
  final List accounts;
  final Widget? footer;

  const _SectionCard({
    required this.title,
    required this.total,
    required this.color,
    required this.accounts,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return KCard(
      statusAccent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: KTypography.h4.copyWith(fontWeight: FontWeight.w700),
              ),
              KMoney(
                total,
                size: KMoneySize.medium,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          KSpacing.vGapSm,
          if (accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No accounts with balance',
                style: KTypography.bodySmall.copyWith(
                  color: KColors.textSecondary,
                ),
              ),
            )
          else
            KDataTable(
              columns: const [
                KTableColumn(label: 'Code'),
                KTableColumn(label: 'Account'),
                KTableColumn(label: 'Balance', numeric: true),
              ],
              rows: [
                ...accounts.map((acct) {
                  final a = acct as Map<String, dynamic>;
                  final amt = (a['amount'] as num?)?.toDouble() ?? 0;
                  return [
                    Text(
                      a['accountCode'] as String? ?? '',
                      style: KTypography.mono(
                        size: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      a['accountName'] as String? ?? '',
                      style: KTypography.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    KMoney(amt, size: KMoneySize.small),
                  ];
                }),
                [
                  Text('', style: KTypography.labelLarge),
                  Text(
                    'TOTAL ${title.toUpperCase()}',
                    style: KTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
                  ),
                  KMoney(
                    total,
                    size: KMoneySize.medium,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          if (footer != null) ...[
            KSpacing.vGapSm,
            footer!,
          ],
        ],
      ),
    );
  }
}
