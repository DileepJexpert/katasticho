import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_typography.dart';
import '../data/dashboard_repository.dart';

/// Quick preset + custom date range picker for the dashboard. Presets
/// give one-tap access to the ranges an owner will actually use; the
/// "Custom" preset opens the platform date range dialog so a specific
/// window can be selected.
///
/// Writes to [dashboardFilterProvider] — every dashboard widget
/// re-fetches on change.
class DashboardDateRangePicker extends ConsumerWidget {
  const DashboardDateRangePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(dashboardFilterProvider);
    final cs = Theme.of(context).colorScheme;
    final preset = _detectPreset(filter);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<_Preset>(
                value: preset,
                isExpanded: true,
                items: [
                  for (final p in _Preset.values)
                    DropdownMenuItem<_Preset>(
                      value: p,
                      child: Text(_labelFor(p, filter),
                          style: KTypography.bodyMedium),
                    ),
                ],
                onChanged: (p) async {
                  if (p == null) return;
                  final newFilter = await _applyPreset(context, p, filter);
                  if (newFilter != null) {
                    ref.read(dashboardFilterProvider.notifier).state = newFilter;
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  static _Preset _detectPreset(DashboardFilter f) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    if (_sameDay(f.from, today) && _sameDay(f.to, today)) return _Preset.today;
    if (_sameDay(f.from, yesterday) && _sameDay(f.to, yesterday)) {
      return _Preset.yesterday;
    }
    if (_sameDay(f.from, weekStart) && _sameDay(f.to, today)) return _Preset.thisWeek;
    if (_sameDay(f.from, monthStart) && _sameDay(f.to, today)) return _Preset.thisMonth;
    return _Preset.custom;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _labelFor(_Preset p, DashboardFilter filter) {
    switch (p) {
      case _Preset.today:
        return 'Today';
      case _Preset.yesterday:
        return 'Yesterday';
      case _Preset.thisWeek:
        return 'This Week';
      case _Preset.thisMonth:
        return 'This Month';
      case _Preset.custom:
        return 'Custom: ${_fmt(filter.from)} – ${_fmt(filter.to)}';
    }
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  static Future<DashboardFilter?> _applyPreset(
      BuildContext context, _Preset p, DashboardFilter current) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (p) {
      case _Preset.today:
        return current.copyWith(from: today, to: today);
      case _Preset.yesterday:
        final y = today.subtract(const Duration(days: 1));
        return current.copyWith(from: y, to: y);
      case _Preset.thisWeek:
        final weekStart = today.subtract(Duration(days: now.weekday - 1));
        return current.copyWith(from: weekStart, to: today);
      case _Preset.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1);
        return current.copyWith(from: monthStart, to: today);
      case _Preset.custom:
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(today.year + 1, today.month, today.day),
          initialDateRange: DateTimeRange(start: current.from, end: current.to),
        );
        if (picked == null) return null;
        return current.copyWith(from: picked.start, to: picked.end);
    }
  }
}

enum _Preset { today, yesterday, thisWeek, thisMonth, custom }
