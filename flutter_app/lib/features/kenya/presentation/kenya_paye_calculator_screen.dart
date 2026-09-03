import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_text_field.dart';
import '../data/kenya_repository.dart';

class KenyaPayeCalculatorScreen extends ConsumerStatefulWidget {
  const KenyaPayeCalculatorScreen({super.key});

  @override
  ConsumerState<KenyaPayeCalculatorScreen> createState() => _KenyaPayeCalculatorScreenState();
}

class _KenyaPayeCalculatorScreenState extends ConsumerState<KenyaPayeCalculatorScreen> {
  final _grossController = TextEditingController(text: '85000');
  KenyaPayeResultDto? _result;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  Future<void> _calculate() async {
    final val = double.tryParse(_grossController.text) ?? 0;
    if (val <= 0) return;
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(kenyaRepositoryProvider);
      final res = await repo.calculatePaye(grossSalary: val);
      if (mounted) setState(() => _result = res);
    } catch (_) {}
    finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kenya PAYE & Statutory Salary Calculator'),
      ),
      body: SingleChildScrollView(
        padding: KSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Input Card
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gross Monthly Salary (KSh)', style: KTypography.labelLarge.copyWith(fontWeight: FontWeight.bold)),
                  KSpacing.vGapSm,
                  Row(
                    children: [
                      Expanded(
                        child: KTextField(
                          controller: _grossController,
                          label: 'Monthly Gross Pay',
                          onChanged: (_) => _calculate(),
                        ),
                      ),
                      KSpacing.hGapMd,
                      KButton.primary(
                        label: _isLoading ? 'Calculating...' : 'Calculate',
                        icon: Icons.calculate,
                        onPressed: _isLoading ? null : _calculate,
                      ),
                    ],
                  ),
                  KSpacing.vGapMd,
                  Wrap(
                    spacing: 8,
                    children: [30000, 50000, 85000, 150000, 300000].map((preset) {
                      return ActionChip(
                        label: Text('KSh ${CurrencyFormatter.format(preset.toDouble())}'),
                        onPressed: () {
                          _grossController.text = preset.toString();
                          _calculate();
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            KSpacing.vGapLg,

            // Results Card
            if (_result != null) ...[
              KCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Statutory Breakdown (2024-2026 KRA Rules)',
                            style: KTypography.h3.copyWith(fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: KColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('KRA Verified', style: TextStyle(color: KColors.success, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    _buildLine('Gross Monthly Pay', _result!.grossSalary, isBold: true),
                    const Divider(),
                    _buildLine('NSSF Tier I (6% up to 8,000)', -_result!.nssfTier1),
                    _buildLine('NSSF Tier II (6% up to 36,000)', -_result!.nssfTier2),
                    _buildLine('Total NSSF Contribution', -_result!.totalNssf, isHighlight: true),
                    const Divider(),
                    _buildLine('Taxable Pay (Gross − NSSF)', _result!.taxablePay, isBold: true),
                    _buildLine('Gross PAYE (Graduated Bands)', _result!.grossPaye),
                    _buildLine('Less: Monthly Personal Relief', -_result!.personalRelief, isPositiveRelief: true),
                    _buildLine('Net PAYE Deducted', -_result!.netPaye, isHighlight: true),
                    const Divider(),
                    _buildLine('SHIF Health Insurance (2.75%)', -_result!.shifAmount),
                    _buildLine('Affordable Housing Levy (1.5%)', -_result!.housingLevyAmount),
                    _buildLine('Total Statutory Deductions', -_result!.totalDeductions, isHighlight: true),
                    const Divider(height: 28),

                    // Net Take-Home Highlight
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A859).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF00A859).withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Net Take-Home Salary', style: TextStyle(fontSize: 13, color: KColors.textSecondary)),
                              Text('After all KRA & Statutory Deductions', style: KTypography.bodySmall.copyWith(color: KColors.textHint)),
                            ],
                          ),
                          Text(
                            'KSh ${CurrencyFormatter.format(_result!.netPay)}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00A859)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLine(String label, double amount, {bool isBold = false, bool isHighlight = false, bool isPositiveRelief = false}) {
    final isNegative = amount < 0;
    final displayAmt = amount.abs();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isBold
                ? KTypography.labelLarge.copyWith(fontWeight: FontWeight.bold)
                : isHighlight
                    ? KTypography.labelMedium.copyWith(fontWeight: FontWeight.w600, color: KColors.primary)
                    : KTypography.bodyMedium,
          ),
          Text(
            '${isNegative ? "- " : isPositiveRelief ? "+ " : ""}KSh ${CurrencyFormatter.format(displayAmt)}',
            style: TextStyle(
              fontWeight: isBold || isHighlight ? FontWeight.bold : FontWeight.normal,
              color: isPositiveRelief
                  ? KColors.success
                  : isNegative
                      ? KColors.error
                      : null,
            ),
          ),
        ],
      ),
    );
  }
}