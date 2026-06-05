import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
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
          SnackBar(content: Text('Failed to load executions: $e')),
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
          SnackBar(content: Text('Failed to initiate day close: $e')),
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
            content: Text('Day close submitted'),
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
          SnackBar(content: Text('Failed to submit day close: $e')),
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
            content: Text('Day close approved'),
            backgroundColor: KColors.success,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve: $e')),
        );
      }
    }
  }

  Future<void> _rejectDayClose(String id) async {
    try {
      await ref.read(fieldSalesRepositoryProvider).rejectDayClose(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Day close rejected')),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Day Close'),
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
          ? const Center(child: CircularProgressIndicator())
          : _isDayCloseMode
              ? _buildDayCloseForm()
              : _buildExecutionsList(),
    );
  }

  Widget _buildExecutionsList() {
    if (_completedExecutions.isEmpty) {
      return const Center(child: Text('No completed executions found'));
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(routeName,
                          style: KTypography.labelLarge,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (dayCloseStatus != null)
                      KStatusChip(
                        status: dayCloseStatus,
                        label: dayCloseStatus.replaceAll('_', ' '),
                      ),
                  ],
                ),
                KSpacing.vGapXs,
                Text('Date: $execDate',
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.textSecondary)),
                KSpacing.vGapXs,
                Text('$completedVisits / $totalVisits visits completed',
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.textSecondary)),
                KSpacing.vGapSm,
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (dayCloseStatus == null ||
                        dayCloseStatus == 'DRAFT')
                      FilledButton.tonal(
                        onPressed: () => _initiateDayClose(id),
                        child: const Text('Initiate Day Close'),
                      ),
                    if (dayCloseStatus == 'SUBMITTED' &&
                        dayCloseId != null) ...[
                      OutlinedButton(
                        onPressed: () => _rejectDayClose(dayCloseId),
                        child: const Text('Reject'),
                      ),
                      KSpacing.hGapSm,
                      FilledButton(
                        onPressed: () => _approveDayClose(dayCloseId),
                        child: const Text('Approve'),
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
        Text('Cash', style: KTypography.labelLarge),
        KSpacing.vGapSm,
        KCard(
          child: Column(
            children: [
              TextField(
                controller: _openingCashCtl,
                decoration: const InputDecoration(
                  labelText: 'Opening Cash',
                ),
                keyboardType: TextInputType.number,
              ),
              KSpacing.vGapSm,
              _ReadOnlyField(
                label: 'Cash Collections',
                value: CurrencyFormatter.formatIndian(cashCollections),
              ),
              KSpacing.vGapSm,
              TextField(
                controller: _cashExpensesCtl,
                decoration: const InputDecoration(
                  labelText: 'Cash Expenses',
                ),
                keyboardType: TextInputType.number,
              ),
              KSpacing.vGapSm,
              TextField(
                controller: _closingCashCtl,
                decoration: const InputDecoration(
                  labelText: 'Closing Cash',
                ),
                keyboardType: TextInputType.number,
              ),
              KSpacing.vGapSm,
              TextField(
                controller: _cashDepositedCtl,
                decoration: const InputDecoration(
                  labelText: 'Cash Deposited',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        KSpacing.vGapMd,

        // -- Stock Section --
        Text('Stock', style: KTypography.labelLarge),
        KSpacing.vGapSm,
        KCard(
          child: Column(
            children: [
              _ReadOnlyField(
                  label: 'Items Loaded', value: '$itemsLoaded'),
              KSpacing.vGapSm,
              _ReadOnlyField(
                  label: 'Items Sold', value: '$itemsSold'),
              KSpacing.vGapSm,
              _ReadOnlyField(
                  label: 'Items Returned', value: '$itemsReturned'),
              KSpacing.vGapSm,
              _ReadOnlyField(
                  label: 'Closing Stock', value: '$itemsClosing'),
            ],
          ),
        ),
        KSpacing.vGapMd,

        // -- Visit Section --
        Text('Visits', style: KTypography.labelLarge),
        KSpacing.vGapSm,
        KCard(
          child: Column(
            children: [
              _ReadOnlyField(
                  label: 'Planned', value: '$plannedVisits'),
              KSpacing.vGapSm,
              _ReadOnlyField(
                  label: 'Completed', value: '$completedVisits'),
              KSpacing.vGapSm,
              _ReadOnlyField(
                  label: 'Productive', value: '$productiveVisits'),
            ],
          ),
        ),
        KSpacing.vGapMd,

        // -- Financial Section --
        Text('Financial', style: KTypography.labelLarge),
        KSpacing.vGapSm,
        KCard(
          child: Column(
            children: [
              _ReadOnlyField(
                label: 'Orders Value',
                value: CurrencyFormatter.formatIndian(ordersValue),
              ),
              KSpacing.vGapSm,
              _ReadOnlyField(
                label: 'Collections',
                value: CurrencyFormatter.formatIndian(totalCollections),
              ),
              KSpacing.vGapSm,
              _ReadOnlyField(
                label: 'Returns',
                value: CurrencyFormatter.formatIndian(returnsValue),
              ),
            ],
          ),
        ),
        KSpacing.vGapMd,

        // -- Notes --
        TextField(
          controller: _notesCtl,
          decoration: const InputDecoration(
            labelText: 'Notes',
            hintText: 'Any observations or remarks...',
          ),
          maxLines: 3,
        ),
        KSpacing.vGapLg,

        // -- Actions --
        if (dayCloseStatus == 'SUBMITTED') ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _activeDayCloseId != null
                      ? () => _rejectDayClose(_activeDayCloseId!)
                      : null,
                  child: const Text('Reject'),
                ),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: FilledButton(
                  onPressed: _activeDayCloseId != null
                      ? () => _approveDayClose(_activeDayCloseId!)
                      : null,
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ] else
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitDayClose,
              child: const Text('Submit Day Close'),
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
        Text(label,
            style: KTypography.bodySmall
                .copyWith(color: KColors.textSecondary)),
        Text(value, style: KTypography.labelMedium),
      ],
    );
  }
}
