import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_text_field.dart';
import '../data/cash_runway_repository.dart';

class CashRunwayScreen extends ConsumerStatefulWidget {
  const CashRunwayScreen({super.key});

  @override
  ConsumerState<CashRunwayScreen> createState() => _CashRunwayScreenState();
}

class _CashRunwayScreenState extends ConsumerState<CashRunwayScreen> {
  bool _isLoading = true;
  bool _isSimulating = false;
  bool _isSimulationActive = false;
  Map<String, dynamic>? _report;

  // Simulation parameters
  double _arDelayDays = 0;
  double _apExtensionDays = 0;
  double _arEfficiency = 100;
  double _revenueAdjustment = 0;
  int _capexWeek = 4;
  final _capexAmountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBaseline();
  }

  @override
  void dispose() {
    _capexAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBaseline() async {
    setState(() {
      _isLoading = true;
      _isSimulationActive = false;
    });
    try {
      final repo = ref.read(cashRunwayRepositoryProvider);
      final data = await repo.get13WeekRunway();
      if (mounted) {
        setState(() {
          _report = data;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load cash runway: ${ApiErrorParser.message(e)}'),
            backgroundColor: KColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _runSimulation() async {
    setState(() => _isSimulating = true);
    try {
      final repo = ref.read(cashRunwayRepositoryProvider);
      final capexVal = double.tryParse(_capexAmountCtrl.text.trim()) ?? 0.0;
      final Map<int, double> capexMap = {};
      if (capexVal > 0) {
        capexMap[_capexWeek] = capexVal;
      }

      final simData = {
        'arDelayDays': _arDelayDays.round(),
        'apExtensionDays': _apExtensionDays.round(),
        'arCollectionEfficiency': _arEfficiency / 100.0,
        'revenueAdjustmentPct': _revenueAdjustment,
        'plannedCapexByWeek': capexMap.map((k, v) => MapEntry(k.toString(), v)),
      };

      final data = await repo.simulateScenario(simulation: simData);
      if (mounted) {
        setState(() {
          _report = data;
          _isSimulationActive = true;
        });
        Navigator.pop(context); // Close simulator drawer
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('What-If Scenario applied! 13-Week forecast recalculated.'),
            backgroundColor: KColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Simulation failed: ${ApiErrorParser.message(e)}'),
            backgroundColor: KColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSimulating = false);
    }
  }

  void _showSimulatorDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDrawerState) => Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: const BoxDecoration(
            color: KColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(KSpacing.radiusLg)),
          ),
          padding: const EdgeInsets.all(KSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune, color: KColors.primary),
                      const SizedBox(width: KSpacing.sm),
                      Text('CFO "What-If" Scenario Simulator', style: KTypography.h3),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Text(
                'Stress-test your 13-week runway by simulating customer payment lags, supplier credit extensions, and planned capital expenditure.',
                style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
              ),
              const Divider(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    // AR Delay Slider
                    Text('Customer AR Collection Delay: +${_arDelayDays.round()} Days', style: KTypography.labelMedium),
                    Slider(
                      value: _arDelayDays,
                      min: 0,
                      max: 45,
                      divisions: 9,
                      label: '+${_arDelayDays.round()}d',
                      onChanged: (v) => setDrawerState(() => _arDelayDays = v),
                    ),
                    const SizedBox(height: KSpacing.sm),

                    // AP Extension Slider
                    Text('Supplier AP Credit Extension: +${_apExtensionDays.round()} Days', style: KTypography.labelMedium),
                    Slider(
                      value: _apExtensionDays,
                      min: 0,
                      max: 45,
                      divisions: 9,
                      label: '+${_apExtensionDays.round()}d',
                      onChanged: (v) => setDrawerState(() => _apExtensionDays = v),
                    ),
                    const SizedBox(height: KSpacing.sm),

                    // AR Collection Efficiency
                    Text('Customer Collection Efficiency: ${_arEfficiency.round()}%', style: KTypography.labelMedium),
                    Slider(
                      value: _arEfficiency,
                      min: 50,
                      max: 100,
                      divisions: 10,
                      label: '${_arEfficiency.round()}%',
                      onChanged: (v) => setDrawerState(() => _arEfficiency = v),
                    ),
                    const SizedBox(height: KSpacing.sm),

                    // Revenue Growth / Decline
                    Text('Pipeline Revenue Variance: ${_revenueAdjustment > 0 ? "+" : ""}${_revenueAdjustment.round()}%', style: KTypography.labelMedium),
                    Slider(
                      value: _revenueAdjustment,
                      min: -40,
                      max: 40,
                      divisions: 16,
                      label: '${_revenueAdjustment.round()}%',
                      onChanged: (v) => setDrawerState(() => _revenueAdjustment = v),
                    ),
                    const SizedBox(height: KSpacing.md),

                    // Planned CapEx Injection
                    Text('Planned Capital Expenditure (CapEx)', style: KTypography.labelMedium),
                    const SizedBox(height: KSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<int>(
                            initialValue: _capexWeek,
                            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), labelText: 'Target Week'),
                            items: List.generate(13, (i) => DropdownMenuItem(value: i + 1, child: Text('Week ${i + 1}'))),
                            onChanged: (v) {
                              if (v != null) setDrawerState(() => _capexWeek = v);
                            },
                          ),
                        ),
                        const SizedBox(width: KSpacing.sm),
                        Expanded(
                          flex: 5,
                          child: KTextField(
                            label: 'CapEx Amount (₹)',
                            controller: _capexAmountCtrl,
                            hint: 'e.g. 500000',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setDrawerState(() {
                        _arDelayDays = 0;
                        _apExtensionDays = 0;
                        _arEfficiency = 100;
                        _revenueAdjustment = 0;
                        _capexAmountCtrl.clear();
                      });
                    },
                    child: const Text('Reset Sliders'),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  KButton(
                    label: _isSimulating ? 'Recalculating...' : 'Apply Simulation',
                    icon: Icons.play_arrow,
                    onPressed: _isSimulating ? null : _runSimulation,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: KColors.bgApp,
        body: Center(child: KLoading()),
      );
    }

    final runwayWeeks = (_report?['runwayWeeks'] as num?)?.toDouble() ?? 52.0;
    final currentCash = (_report?['currentLiquidCash'] as num?)?.toDouble() ?? 0.0;
    final minBal = (_report?['minProjectedBalance'] as num?)?.toDouble() ?? 0.0;
    final minWeek = _report?['minBalanceWeek'] ?? 1;
    final net13W = (_report?['netChange13W'] as num?)?.toDouble() ?? 0.0;
    final deficitCount = _report?['deficitWeeksCount'] ?? 0;
    final alerts = (_report?['deficitAlerts'] as List? ?? []).whereType<String>().toList();
    final buckets = (_report?['weeklyBuckets'] as List? ?? []).whereType<Map<String, dynamic>>().toList();

    return Scaffold(
      backgroundColor: KColors.bgApp,
      appBar: AppBar(
        title: Text('13-Week Rolling Cash Flow Runway', style: KTypography.h3),
        actions: [
          if (_isSimulationActive)
            Padding(
              padding: const EdgeInsets.only(right: KSpacing.sm),
              child: Chip(
                avatar: const Icon(Icons.science_outlined, size: 16, color: KColors.warning),
                label: const Text('Simulated Scenario Active', style: TextStyle(color: KColors.warning, fontWeight: FontWeight.w700)),
                backgroundColor: KColors.warningLight,
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: _loadBaseline,
              ),
            ),
          KButton(
            label: 'What-If Sandbox',
            icon: Icons.tune,
            variant: KButtonVariant.secondary,
            size: KButtonSize.small,
            onPressed: _showSimulatorDrawer,
          ),
          const SizedBox(width: KSpacing.sm),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBaseline,
          ),
          const SizedBox(width: KSpacing.sm),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(KSpacing.md),
        children: [
          // KPI Summary Ribbon
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  'Projected Cash Runway',
                  '${runwayWeeks >= 52 ? "> 52" : runwayWeeks.toStringAsFixed(1)} Weeks',
                  runwayWeeks > 12 ? KColors.success : (runwayWeeks > 6 ? KColors.warning : KColors.error),
                  Icons.speed,
                  subtitle: runwayWeeks > 12 ? 'Healthy Liquidity Runway' : 'Action Needed: Extend Runway',
                ),
              ),
              const SizedBox(width: KSpacing.sm),
              Expanded(
                child: _buildMoneyKpi(
                  'Live Liquid Cash',
                  currentCash,
                  KColors.primary,
                  Icons.account_balance_wallet_outlined,
                  subtitle: 'Bank Accounts + Cash in Hand',
                ),
              ),
              const SizedBox(width: KSpacing.sm),
              Expanded(
                child: _buildMoneyKpi(
                  'Lowest Projected Balance',
                  minBal,
                  minBal < 100000 ? KColors.error : KColors.textPrimary,
                  Icons.trending_down,
                  subtitle: 'Trough occurs in Week $minWeek',
                ),
              ),
              const SizedBox(width: KSpacing.sm),
              Expanded(
                child: _buildMoneyKpi(
                  '13-Week Net Cash Flow',
                  net13W,
                  net13W >= 0 ? KColors.success : KColors.error,
                  net13W >= 0 ? Icons.north_east : Icons.south_east,
                  subtitle: net13W >= 0 ? 'Projected Surplus' : 'Projected Deficit',
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.md),

          // Deficit Alerts Banner
          if (deficitCount > 0 && alerts.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(KSpacing.md),
              decoration: BoxDecoration(
                color: KColors.errorLight,
                border: Border.all(color: KColors.error.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(KSpacing.radiusSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: KColors.error, size: 20),
                      const SizedBox(width: KSpacing.xs),
                      Text(
                        'CFO Liquidity Alert: $deficitCount Week(s) Dip Below Safety Buffer',
                        style: KTypography.h4.copyWith(color: KColors.error, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: KSpacing.xs),
                  ...alerts.map((a) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: KColors.error, fontWeight: FontWeight.w700)),
                        Expanded(child: Text(a, style: KTypography.bodySmall.copyWith(color: KColors.textPrimary))),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: KSpacing.md),
          ],

          // 13-Week Visual Chart Timeline
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('13-Week Rolling Liquidity Trajectory', style: KTypography.h3),
                    Text('Safety Buffer: ₹1,00,000', style: KTypography.caption.copyWith(color: KColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: KSpacing.lg),
                SizedBox(
                  height: 160,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: buckets.map((b) {
                      final closing = (b['closingBalance'] as num?)?.toDouble() ?? 0.0;
                      final isDef = b['isDeficit'] == true;
                      final maxH = currentCash.abs() * 1.5;
                      final ratio = maxH > 0 ? (closing.abs() / maxH).clamp(0.08, 1.0) : 0.1;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '₹${(closing / 1000).toStringAsFixed(0)}k',
                                style: KTypography.caption.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isDef ? KColors.error : KColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: 110 * ratio,
                                decoration: BoxDecoration(
                                  color: isDef ? KColors.error.withValues(alpha: 0.8) : KColors.primary.withValues(alpha: 0.75),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'W${b['weekNumber']}',
                                style: KTypography.caption.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpacing.md),

          // 13-Week Data Matrix Table
          KCard(
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(KColors.bgApp),
                columns: [
                  const DataColumn(label: Text('Line Item / Metric', style: TextStyle(fontWeight: FontWeight.w700))),
                  ...buckets.map((b) => DataColumn(
                    label: Text(
                      'W${b['weekNumber']}\n${b['weekLabel']?.toString().split(' ')[1] ?? ""}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                  )),
                ],
                rows: [
                  _dataRow('Opening Balance', buckets, (b) => (b['openingBalance'] as num?)?.toDouble() ?? 0.0, isBold: true),
                  _dataRow('(+) AR Invoice Collections', buckets, (b) => (b['arInvoices'] as num?)?.toDouble() ?? 0.0, color: KColors.success),
                  _dataRow('(+) Pipeline Sales Orders', buckets, (b) => (b['salesOrdersPipeline'] as num?)?.toDouble() ?? 0.0, color: KColors.success),
                  _dataRow('(+) Recurring Revenue', buckets, (b) => (b['recurringRevenue'] as num?)?.toDouble() ?? 0.0, color: KColors.success),
                  _dataRow('Total Inflows', buckets, (b) => (b['totalInflows'] as num?)?.toDouble() ?? 0.0, isBold: true, color: KColors.success),
                  _dataRow('(-) AP Vendor Bills', buckets, (b) => (b['apBills'] as num?)?.toDouble() ?? 0.0, color: KColors.error),
                  _dataRow('(-) PO Pipeline Deliveries', buckets, (b) => (b['purchaseOrdersPipeline'] as num?)?.toDouble() ?? 0.0, color: KColors.error),
                  _dataRow('(-) Payroll Runs', buckets, (b) => (b['payroll'] as num?)?.toDouble() ?? 0.0, color: KColors.error),
                  _dataRow('(-) Statutory Tax (GST/TDS/PF)', buckets, (b) => (b['statutoryTax'] as num?)?.toDouble() ?? 0.0, color: KColors.error),
                  _dataRow('(-) Baseline Opex', buckets, (b) => (b['operatingExpenses'] as num?)?.toDouble() ?? 0.0, color: KColors.error),
                  _dataRow('(-) Planned CapEx', buckets, (b) => (b['plannedCapex'] as num?)?.toDouble() ?? 0.0, color: KColors.warning),
                  _dataRow('Total Outflows', buckets, (b) => (b['totalOutflows'] as num?)?.toDouble() ?? 0.0, isBold: true, color: KColors.error),
                  _dataRow('(=) Net Weekly Flow', buckets, (b) => (b['netCashFlow'] as num?)?.toDouble() ?? 0.0, isBold: true),
                  _dataRow('Closing Balance', buckets, (b) => (b['closingBalance'] as num?)?.toDouble() ?? 0.0, isBold: true, isClosing: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: KSpacing.xxl),
        ],
      ),
    );
  }

  DataRow _dataRow(String title, List<Map<String, dynamic>> buckets, double Function(Map<String, dynamic>) extractor, {bool isBold = false, Color? color, bool isClosing = false}) {
    return DataRow(
      cells: [
        DataCell(Text(title, style: TextStyle(fontWeight: isBold ? FontWeight.w700 : FontWeight.w500))),
        ...buckets.map((b) {
          final val = extractor(b);
          final isDef = isClosing && b['isDeficit'] == true;
          return DataCell(
            Text(
              '₹${val.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
                color: isDef ? KColors.error : color,
                fontSize: 12,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, Color color, IconData icon, {String? subtitle}) {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: KTypography.caption.copyWith(color: KColors.textSecondary)),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: KTypography.h2.copyWith(color: color, fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: KTypography.caption.copyWith(color: KColors.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _buildMoneyKpi(String title, double amount, Color color, IconData icon, {String? subtitle}) {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: KTypography.caption.copyWith(color: KColors.textSecondary)),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 4),
          KMoney(amount, style: KTypography.h3.copyWith(color: color, fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: KTypography.caption.copyWith(color: KColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}
