import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(fiscalPeriodsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final periods = ref.watch(fiscalPeriodsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Period Close')),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(fiscalPeriodsProvider.future),
        child: ListView(
          padding: KSpacing.pagePadding,
          children: [
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
                            : (value) => setState(() => _month = value!),
                      ),
                      SizedBox(
                        width: 96,
                        child: TextFormField(
                          initialValue: _year.toString(),
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Year'),
                          onChanged: (value) =>
                              _year = int.tryParse(value) ?? _year,
                        ),
                      ),
                      KButton(
                        label: 'Close',
                        icon: Icons.lock_clock_outlined,
                        onPressed: _busy
                            ? null
                            : () => _run(() => ref
                                .read(fiscalPeriodRepositoryProvider)
                                .closePeriod(_year, _month)),
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
}
