import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';
import '../data/field_sales_repository.dart';

class DayCloseScreen extends ConsumerStatefulWidget {
  const DayCloseScreen({super.key});

  @override
  ConsumerState<DayCloseScreen> createState() => _DayCloseScreenState();
}

class _DayCloseScreenState extends ConsumerState<DayCloseScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _completedExecutions = [];
  Map<String, dynamic>? _dayCloseData;
  String? _activeDayCloseId;
  bool _isDayCloseMode = false;

  final _openingCashCtl = TextEditingController();
  final _cashExpensesCtl = TextEditingController();
  final _closingCashCtl = TextEditingController();
  final _cashDepositedCtl = TextEditingController();
  final _notesCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _openingCashCtl.dispose();
    _cashExpensesCtl.dispose();
    _closingCashCtl.dispose();
    _cashDepositedCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final executions =
          await ref.read(fieldSalesRepositoryProvider).listExecutions();
      if (mounted) {
        setState(() {
          _completedExecutions = executions
              .where((e) => e['status']?.toString() == 'COMPLETED')
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load executions: $e'),
            backgroundColor: KColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initiateDayClose(String executionId) async {
    setState(() => _isLoading = true);
    try {
      final dayClose = await ref
          .read(fieldSalesRepositoryProvider)
          .initiateDayClose(executionId);
      if (mounted) {
        setState(() {
          _dayCloseData = dayClose;
          _activeDayCloseId = dayClose['id']?.toString();
          _isDayCloseMode = true;

          // Pre-fill read-only data from API
          _openingCashCtl.text =
              (dayClose['openingCash'] as num?)?.toString() ?? '';
          _cashExpensesCtl.text =
              (dayClose['cashExpenses'] as num?)?.toString() ?? '';
          _closingCashCtl.text = '';
          _cashDepositedCtl.text = '';
          _notesCtl.text = '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initiate day close: $e'),
            backgroundColor: KColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitDayClose() async {
    if (_activeDayCloseId == null) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(fieldSalesRepositoryProvider).submitDayClose(
        _activeDayCloseId!,
        {
          if (_closingCashCtl.text.trim().isNotEmpty)
            'closingCash':
                double.tryParse(_closingCashCtl.text.trim()) ?? 0,
          if (_cashDepositedCtl.text.trim().isNotEmpty)
            'cashDeposited':
                double.tryParse(_cashDepositedCtl.text.trim()) ?? 0,
          if (_notesCtl.text.trim().isNotEmpty) 'notes': _notesCtl.text.trim(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Day close submitted successfully'),
            backgroundColor: KColors.success,
          ),
        );
        setState(() {
          _isDayCloseMode = false;
          _dayCloseData = null;
          _activeDayCloseId = null;
        });
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit day close: $e'),
            backgroundColor: KColors.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _approveDayClose(String id) async {
    try {
      await ref.read(fieldSalesRepositoryProvider).approveDayClose(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Day close approved successfully'),
            backgroundColor: KColors.success,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve: $e'),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectDayClose(String id) async {
    try {
      await ref.read(fieldSalesRepositoryProvider).rejectDayClose(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Day close rejected'),
            backgroundColor: KColors.warning,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject: $e'),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Day Close & Cash Reconciliation'),
        leading: _isDayCloseMode
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _isDayCloseMode = false;
                  _dayCloseData = null;
                  _activeDayCloseId = null;
                }),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: KLoading())
          : _isDayCloseMode
              ? _buildDayCloseForm()
              : _buildExecutionsList(),
    );
  }

  Widget _buildExecutionsList() {
    if (_completedExecutions.isEmpty) {
      return const KEmptyState(
        icon: Icons.checklist_rtl_outlined,
        title: 'No completed executions found',
        subtitle: 'Once field salespeople complete their daily routes, they will appear here for day-end reconciliation.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: KSpacing.pagePadding,
        itemCount: _completedExecutions.length,
        separatorBuilder: (_, __) => KSpacing.vGapSm,
        itemBuilder: (context, index) {
          final exec = _completedExecutions[index];
          final id = exec['id']?.toString() ?? '';
          final routeName = exec['routeName']?.toString() ??
              exec['routeId']?.toString() ??
              '--';
          final execDate = exec['date']?.toString() ?? '--';
          final totalVisits =
              (exec['totalVisits'] as num?)?.toInt() ?? 0;
          final completedVisits =
              (exec['completedVisits'] as num?)?.toInt() ?? 0;
          final dayCloseStatus = exec['dayCloseStatus']?.toString();
          final dayCloseId = exec['dayCloseId']?.toString();

          return KCard(
            titleWidget: Row(
              children: [
                Expanded(
                  child: Text(
                    routeName,
                    style: KTypography.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (dayCloseStatus != null)
                  KStatusChip(
                    status: dayCloseStatus,
                    label: dayCloseStatus.replaceAll('_', ' '),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Date: ', style: KTypography.bodySmall),
                    Text(
                      execDate,
                      style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const Text('  •  Visits: '),
                    Text(
                      '$completedVisits / $totalVisits completed',
                      style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                KSpacing.vGapMd,
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (dayCloseStatus == null || dayCloseStatus == 'DRAFT')
                      KButton.primary(
                        label: 'Initiate Day Close',
                        icon: Icons.account_balance_wallet_outlined,
                        onPressed: () => _initiateDayClose(id),
                      ),
                    if (dayCloseStatus == 'SUBMITTED' && dayCloseId != null) ...[
                      KButton.danger(
                        label: 'Reject',
                        icon: Icons.close,
                        onPressed: () => _rejectDayClose(dayCloseId),
                      ),
                      KSpacing.hGapSm,
                      KButton.primary(
                        label: 'Approve',
                        icon: Icons.check,
                        onPressed: () => _approveDayClose(dayCloseId),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayCloseForm() {
    final dc = _dayCloseData ?? {};
    final cashCollections =
        (dc['cashCollections'] as num?)?.toDouble() ?? 0;
    final itemsLoaded = (dc['itemsLoaded'] as num?)?.toInt() ?? 0;
    final itemsSold = (dc['itemsSold'] as num?)?.toInt() ?? 0;
    final itemsReturned = (dc['itemsReturned'] as num?)?.toInt() ?? 0;
    final itemsClosing = (dc['itemsClosing'] as num?)?.toInt() ?? 0;
    final plannedVisits = (dc['plannedVisits'] as num?)?.toInt() ?? 0;
    final completedVisits = (dc['completedVisits'] as num?)?.toInt() ?? 0;
    final productiveVisits = (dc['productiveVisits'] as num?)?.toInt() ?? 0;
    final ordersValue = (dc['ordersValue'] as num?)?.toDouble() ?? 0;
    final totalCollections =
        (dc['totalCollections'] as num?)?.toDouble() ?? 0;
    final returnsValue = (dc['returnsValue'] as num?)?.toDouble() ?? 0;
    final dayCloseStatus = dc['status']?.toString();

    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        // -- Cash Section --
        KCard(
          title: 'Cash Reconciliation',
          leading: const Icon(Icons.payments_outlined, color: KColors.primary),
          child: Column(
            children: [
              KTextField.amount(
                label: 'Opening Cash',
                controller: _openingCashCtl,
              ),
              KSpacing.vGapSm,
              _ReadOnlyMoneyField(
                label: 'Cash Collections',
                amount: cashCollections,
              ),
              KSpacing.vGapSm,
              KTextField.amount(
                label: 'Cash Expenses',
                controller: _cashExpensesCtl,
              ),
              KSpacing.vGapSm,
              KTextField.amount(
                label: 'Closing Cash',
                controller: _closingCashCtl,
              ),
              KSpacing.vGapSm,
              KTextField.amount(
                label: 'Cash Deposited (Bank/Safe)',
                controller: _cashDepositedCtl,
              ),
            ],
          ),
        ),
        KSpacing.vGapMd,

        // -- Stock Section --
        KCard(
          title: 'Van Stock Reconciliation',
          leading: const Icon(Icons.inventory_2_outlined, color: KColors.primary),
          child: Column(
            children: [
              _ReadOnlyField(
                label: 'Items Loaded',
                value: '$itemsLoaded',
              ),
              KSpacing.vGapSm,
              _ReadOnlyField(
                label: 'Items Sold',
                value: '$itemsSold',
              ),
              KSpacing.vGapSm,
              _ReadOnlyField(
                label: 'Items Returned',
                value: '$itemsReturned',
              ),
              KSpacing.vGapSm,
              _ReadOnlyField(
                label: 'Closing Stock (In Van)',
                value: '$itemsClosing',
              ),
            ],
          ),
        ),
        KSpacing.vGapMd,

        // -- Visit Section --
        KCard(
          title: 'Visit Summary',
          leading: const Icon(Icons.pin_drop_outlined, color: KColors.primary),
          child: Column(
            children: [
              _ReadOnlyField(
                label: 'Planned Stops',
                value: '$plannedVisits',
              ),
              KSpacing.vGapSm,
              _ReadOnlyField(
                label: 'Completed Stops',
                value: '$completedVisits',
              ),
              KSpacing.vGapSm,
              _ReadOnlyField(
                label: 'Productive Orders',
                value: '$productiveVisits',
              ),
            ],
          ),
        ),
        KSpacing.vGapMd,

        // -- Financial Section --
        KCard(
          title: 'Financial Summary',
          leading: const Icon(Icons.account_balance_outlined, color: KColors.primary),
          child: Column(
            children: [
              _ReadOnlyMoneyField(
                label: 'Total Orders Booked',
                amount: ordersValue,
              ),
              KSpacing.vGapSm,
              _ReadOnlyMoneyField(
                label: 'Total Collections (Cash + Digital)',
                amount: totalCollections,
              ),
              KSpacing.vGapSm,
              _ReadOnlyMoneyField(
                label: 'Sales Returns',
                amount: returnsValue,
              ),
            ],
          ),
        ),
        KSpacing.vGapMd,

        // -- Notes --
        KTextField(
          controller: _notesCtl,
          label: 'Notes & Observations',
          hint: 'Any remarks or collection discrepancies...',
          maxLines: 3,
        ),
        KSpacing.vGapLg,

        // -- Actions --
        if (dayCloseStatus == 'SUBMITTED') ...[
          Row(
            children: [
              Expanded(
                child: KButton.danger(
                  label: 'Reject',
                  icon: Icons.close,
                  onPressed: _activeDayCloseId != null
                      ? () => _rejectDayClose(_activeDayCloseId!)
                      : null,
                ),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: KButton.primary(
                  label: 'Approve',
                  icon: Icons.check,
                  onPressed: _activeDayCloseId != null
                      ? () => _approveDayClose(_activeDayCloseId!)
                      : null,
                ),
              ),
            ],
          ),
        ] else
          SizedBox(
            width: double.infinity,
            child: KButton.primary(
              label: 'Submit Day Close',
              icon: Icons.send_outlined,
              onPressed: _submitDayClose,
            ),
          ),
        KSpacing.vGapLg,
      ],
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: KTypography.bodyMedium.copyWith(color: KColors.textSecondary),
        ),
        Text(
          value,
          style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ReadOnlyMoneyField extends StatelessWidget {
  final String label;
  final double amount;

  const _ReadOnlyMoneyField({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: KTypography.bodyMedium.copyWith(color: KColors.textSecondary),
        ),
        KMoney(
          amount,
          size: KMoneySize.small,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
