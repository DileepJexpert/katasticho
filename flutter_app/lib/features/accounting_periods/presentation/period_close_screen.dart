import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/fiscal_period_repository.dart';

class PeriodCloseScreen extends ConsumerStatefulWidget {
  const PeriodCloseScreen({super.key});

  @override
  ConsumerState<PeriodCloseScreen> createState() => _PeriodCloseScreenState();
}

class _PeriodCloseScreenState extends ConsumerState<PeriodCloseScreen> {
  late int _year;
  late int _month;
  bool _busy = false;

  late int _yecYear;
  bool _yecBusy = false;
  Map<String, dynamic>? _yecResult;

  bool _checklistLoading = false;
  Map<String, dynamic>? _checklist;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    // Default to the most recently completed fiscal year (FY starts in April).
    _yecYear = now.month >= 4 ? now.year - 1 : now.year - 2;
    _loadChecklist();
  }

  Future<void> _loadChecklist() async {
    final year = _year;
    final month = _month;
    setState(() => _checklistLoading = true);
    try {
      final res = await ref
          .read(apiClientProvider)
          .get(ApiConfig.closeChecklist(year, month));
      final data = (res.data as Map<String, dynamic>)['data'];
      if (!mounted) return;
      // Ignore a stale response if the selection changed mid-flight.
      if (year != _year || month != _month) return;
      setState(() => _checklist =
          data is Map ? Map<String, dynamic>.from(data) : null);
    } catch (_) {
      if (!mounted) return;
      if (year != _year || month != _month) return;
      setState(() => _checklist = null);
    } finally {
      if (mounted) setState(() => _checklistLoading = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(fiscalPeriodsProvider);
      await _loadChecklist();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Route the Close button through the guarded continuous-close endpoint.
  Future<void> _guardedClose() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(apiClientProvider)
          .post(ApiConfig.guardedClose(_year, _month));
      await _onCloseSuccess();
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        await _promptForceClose(e);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? e.toString())),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _promptForceClose(DioException error) async {
    if (!mounted) return;
    final data = error.response?.data;
    final message = (data is Map && data['message'] != null)
        ? data['message'].toString()
        : 'Period is not ready to close.';
    final force = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Period not ready'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Close anyway'),
          ),
        ],
      ),
    );
    if (force != true) return;
    try {
      await ref.read(apiClientProvider).post(
            ApiConfig.guardedClose(_year, _month),
            queryParameters: {'force': true},
          );
      await _onCloseSuccess(forced: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _onCloseSuccess({bool forced = false}) async {
    ref.invalidate(fiscalPeriodsProvider);
    await _loadChecklist();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          forced
              ? '${_months[_month - 1]} $_year closed (forced).'
              : '${_months[_month - 1]} $_year closed.',
        ),
      ),
    );
  }

  Future<void> _runYearEndClose() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Close FY $_yecYear?'),
        content: const Text(
          "Posts the closing entry that moves the year's net P&L into Retained "
          'Earnings. It can be reversed from the journal if needed.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Close year')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _yecBusy = true);
    try {
      final result =
          await ref.read(fiscalPeriodRepositoryProvider).yearEndClose(_yecYear);
      if (!mounted) return;
      setState(() => _yecResult = result);
      ref.invalidate(fiscalPeriodsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('FY $_yecYear closed.')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final msg = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : (e.message ?? e.toString());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _yecBusy = false);
    }
  }

  Widget _yearEndCloseCard() {
    final r = _yecResult;
    final nothing = r != null && r['journalEntryId'] == null;
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Year-end close', style: KTypography.h3),
          const SizedBox(height: 4),
          Text("Zero the year's P&L into Retained Earnings (3020).",
              style: KTypography.bodySmall),
          KSpacing.vGapMd,
          Row(
            children: [
              Text('Fiscal year', style: KTypography.labelMedium),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _yecBusy ? null : () => setState(() => _yecYear--),
              ),
              Text('$_yecYear', style: KTypography.labelMedium),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _yecBusy ? null : () => setState(() => _yecYear++),
              ),
              const Spacer(),
              KButton(
                label: 'Close year',
                isLoading: _yecBusy,
                onPressed: _yecBusy ? null : _runYearEndClose,
              ),
            ],
          ),
          if (r != null) ...[
            KSpacing.vGapMd,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (nothing ? KColors.textHint : KColors.success)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nothing
                        ? "No P&L activity for FY ${r['fiscalYear']} — nothing to close."
                        : "Closed FY ${r['fiscalYear']}.",
                    style: KTypography.labelMedium,
                  ),
                  if (!nothing) ...[
                    const SizedBox(height: 4),
                    Text("Net income: ₹${r['netIncome']}",
                        style: KTypography.bodySmall),
                    Text("Accounts closed: ${r['plAccountsClosed']}",
                        style: KTypography.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final periods = ref.watch(fiscalPeriodsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Period Close')),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.refresh(fiscalPeriodsProvider.future),
            _loadChecklist(),
          ]);
        },
        child: ListView(
          padding: KSpacing.pagePadding,
          children: [
            _yearEndCloseCard(),
            KSpacing.vGapMd,
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Accounting lock control', style: KTypography.h3),
                  KSpacing.vGapXs,
                  Text(
                    'Close a month after review to stop accidental backdated postings. Lock it when finalised by owner or CA.',
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.textSecondary),
                  ),
                  KSpacing.vGapMd,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DropdownButton<int>(
                        value: _month,
                        items: [
                          for (var i = 1; i <= 12; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text(_months[i - 1]),
                            )
                        ],
                        onChanged: _busy
                            ? null
                            : (value) {
                                setState(() => _month = value!);
                                _loadChecklist();
                              },
                      ),
                      SizedBox(
                        width: 96,
                        child: TextFormField(
                          initialValue: _year.toString(),
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Year'),
                          onChanged: (value) {
                            _year = int.tryParse(value) ?? _year;
                            _loadChecklist();
                          },
                        ),
                      ),
                      KButton(
                        label: 'Close',
                        icon: Icons.lock_clock_outlined,
                        onPressed: _busy ? null : _guardedClose,
                      ),
                      KButton(
                        label: 'Reopen',
                        icon: Icons.lock_open_outlined,
                        variant: KButtonVariant.outlined,
                        onPressed: _busy
                            ? null
                            : () => _run(() => ref
                                .read(fiscalPeriodRepositoryProvider)
                                .reopenPeriod(_year, _month)),
                      ),
                      KButton(
                        label: 'Lock',
                        icon: Icons.lock_outline,
                        variant: KButtonVariant.danger,
                        onPressed: _busy
                            ? null
                            : () => _run(() => ref
                                .read(fiscalPeriodRepositoryProvider)
                                .lockPeriod(_year, _month)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            KSpacing.vGapMd,
            _buildChecklistCard(),
            KSpacing.vGapMd,
            periods.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  KErrorBanner(message: 'Failed to load periods: $error'),
              data: (items) {
                if (items.isEmpty) {
                  return const KEmptyState(
                    icon: Icons.event_available_outlined,
                    title: 'No closed periods yet',
                    subtitle: 'Close your first month after review.',
                  );
                }
                return Column(
                  children: [
                    for (final period in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: KCard(
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month_outlined),
                              KSpacing.hGapMd,
                              Expanded(
                                child: Text(
                                  '${_months[((period['periodMonth'] as num).toInt()) - 1]} ${period['periodYear']}',
                                  style: KTypography.labelLarge,
                                ),
                              ),
                              KStatusChip(
                                status: period['status']?.toString() ?? 'OPEN',
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistCard() {
    final checklist = _checklist;
    final percent = (checklist?['percentComplete'] as num?)?.toInt() ?? 0;
    final readyToClose = checklist?['readyToClose'] == true;
    final items = (checklist?['items'] as List?) ?? const [];
    final pendingCount = items
        .whereType<Map>()
        .where((i) => (i['status']?.toString().toUpperCase()) == 'PENDING')
        .length;

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Close readiness', style: KTypography.h3),
              KSpacing.hGapSm,
              Text(
                '${_months[_month - 1]} $_year',
                style: KTypography.bodySmall
                    .copyWith(color: KColors.textSecondary),
              ),
              const Spacer(),
              if (_checklistLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: readyToClose
                        ? KColors.successLight
                        : KColors.warningLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$percent%',
                    style: KTypography.labelLarge.copyWith(
                      color:
                          readyToClose ? KColors.success : KColors.warning,
                    ),
                  ),
                ),
            ],
          ),
          KSpacing.vGapSm,
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: KColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(
                readyToClose ? KColors.success : KColors.warning,
              ),
            ),
          ),
          KSpacing.vGapMd,
          if (checklist == null && !_checklistLoading)
            Text(
              'Checklist unavailable.',
              style: KTypography.bodySmall
                  .copyWith(color: KColors.textSecondary),
            )
          else ...[
            for (final raw in items.whereType<Map>())
              _buildChecklistRow(Map<String, dynamic>.from(raw)),
            KSpacing.vGapSm,
            if (readyToClose)
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: KColors.success, size: 18),
                  KSpacing.hGapSm,
                  Text(
                    'Ready to close',
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.success),
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: KColors.warning, size: 18),
                  KSpacing.hGapSm,
                  Text(
                    '$pendingCount task${pendingCount == 1 ? '' : 's'} pending',
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.warning),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklistRow(Map<String, dynamic> item) {
    final status = (item['status']?.toString() ?? 'NA').toUpperCase();
    final label = item['label']?.toString() ?? '';
    final detail = item['detail']?.toString() ?? '';

    final (IconData icon, Color color) = switch (status) {
      'DONE' => (Icons.check_circle, KColors.success),
      'PENDING' => (Icons.warning_amber_rounded, KColors.warning),
      _ => (Icons.remove, KColors.textHint),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: color, size: 18),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: KTypography.labelLarge),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
