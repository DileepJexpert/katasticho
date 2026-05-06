import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../data/report_repository.dart';

class TrialBalanceScreen extends ConsumerStatefulWidget {
  const TrialBalanceScreen({super.key});

  @override
  ConsumerState<TrialBalanceScreen> createState() => _TrialBalanceScreenState();
}

class _TrialBalanceScreenState extends ConsumerState<TrialBalanceScreen> {
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
      final data = await repo.getTrialBalance(
        asOfDate: DateFormatter.api(_asOfDate),
      );
      setState(() => _report = (data['data'] ?? data) as Map<String, dynamic>);
    } catch (e) {
      setState(() => _error = 'Failed to load trial balance');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trial Balance')),
      body: Column(
        children: [
          // Date picker bar
          Container(
            color: KColors.surface,
            padding: const EdgeInsets.all(KSpacing.md),
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

          // Content
          Expanded(
            child: _isLoading
                ? const KLoading(message: 'Generating trial balance...')
                : _error != null
                    ? KErrorView(message: _error!, onRetry: _loadReport)
                    : _report == null
                        ? const KEmptyState(
                            icon: Icons.balance,
                            title: 'Generate a trial balance',
                            subtitle: 'Select a date and tap Generate',
                          )
                        : _buildReport(),
          ),
        ],
      ),
    );
  }

  Widget _buildReport() {
    final lines = (_report!['lines'] as List?) ?? [];
    final totalDebit = (_report!['totalDebit'] as num?)?.toDouble() ?? 0;
    final totalCredit = (_report!['totalCredit'] as num?)?.toDouble() ?? 0;
    final isBalanced = _report!['isBalanced'] as bool? ?? false;
    final difference = (totalDebit - totalCredit).abs();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < KSpacing.tabletBreakpoint;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
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
                                ? 'Balanced as of ${DateFormatter.display(_asOfDate)}'
                                : 'Out of balance by ${CurrencyFormatter.formatIndian(difference)}',
                            style: KTypography.labelLarge.copyWith(
                              color: isBalanced ? KColors.success : KColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  KSpacing.vGapSm,
                  if (narrow)
                    Column(
                      children: [
                        _SummaryTile(label: 'Debit', amount: totalDebit),
                        KSpacing.vGapSm,
                        _SummaryTile(label: 'Credit', amount: totalCredit),
                        KSpacing.vGapSm,
                        _SummaryTile(label: 'Difference', amount: difference),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(child: _SummaryTile(label: 'Debit', amount: totalDebit)),
                        KSpacing.hGapSm,
                        Expanded(child: _SummaryTile(label: 'Credit', amount: totalCredit)),
                        KSpacing.hGapSm,
                        Expanded(child: _SummaryTile(label: 'Difference', amount: difference)),
                      ],
                    ),
                ],
              );
            },
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
            child: KDataTable(
              columns: const [
                KTableColumn(label: 'Code'),
                KTableColumn(label: 'Account'),
                KTableColumn(label: 'Debit', numeric: true),
                KTableColumn(label: 'Credit', numeric: true),
              ],
              rows: [
                ...lines.map((line) {
                  final l = line as Map<String, dynamic>;
                  return [
                    Text(l['accountCode'] as String? ?? '',
                        style: KTypography.bodySmall),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
                      child: Text(
                        l['accountName'] as String? ?? '',
                        style: KTypography.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatIndian(
                          (l['debit'] as num?)?.toDouble() ?? 0),
                      style: KTypography.amountSmall,
                    ),
                    Text(
                      CurrencyFormatter.formatIndian(
                          (l['credit'] as num?)?.toDouble() ?? 0),
                      style: KTypography.amountSmall,
                    ),
                  ];
                }),
                [
                  Text('', style: KTypography.labelLarge),
                  Text('TOTAL', style: KTypography.labelLarge),
                  Text(
                    CurrencyFormatter.formatIndian(totalDebit),
                    style: KTypography.amountMedium,
                  ),
                  Text(
                    CurrencyFormatter.formatIndian(totalCredit),
                    style: KTypography.amountMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final double amount;

  const _SummaryTile({
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: KSpacing.borderRadiusMd,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: KTypography.bodySmall),
          Flexible(
            child: Text(
              CurrencyFormatter.formatIndian(amount),
              style: KTypography.amountSmall,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
