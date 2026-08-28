import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_compact_row.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';

/// HR Shift management — Core HR module.
class ShiftManagementScreen extends ConsumerStatefulWidget {
  const ShiftManagementScreen({super.key});

  @override
  ConsumerState<ShiftManagementScreen> createState() => _ShiftManagementScreenState();
}

class _ShiftManagementScreenState extends ConsumerState<ShiftManagementScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _shifts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get(ApiConfig.hrShifts);
      if (!mounted) return;
      setState(() =>
          _shifts = (res.data['data'] as List?)?.cast<Map<String, dynamic>>() ?? []);
    } catch (e) {
      _toast('Failed to load shifts: ${ApiErrorParser.message(e)}', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String m, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: isError ? KColors.error : null,
      ),
    );
  }

  String _hms(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _create() async {
    final code = TextEditingController();
    final name = TextEditingController();
    final offs = TextEditingController(text: 'SAT,SUN');
    TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 18, minute: 0);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Define Work Shift', style: KTypography.titleLarge),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KTextField(
                    controller: code,
                    label: 'Shift Code *',
                    hint: 'e.g. GEN, MORNING, NIGHT',
                  ),
                  KSpacing.vGapSm,
                  KTextField(
                    controller: name,
                    label: 'Shift Name *',
                    hint: 'e.g. General Day Shift',
                  ),
                  KSpacing.vGapSm,
                  KCompactRow(children: [
                    KCard(
                      onTap: () async {
                        final t = await showTimePicker(context: ctx, initialTime: start);
                        if (t != null) setD(() => start = t);
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.login_rounded, size: 16, color: KColors.success),
                          KSpacing.hGapSm,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Start Time', style: KTypography.labelSmall),
                                Text(start.format(ctx), style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    KCard(
                      onTap: () async {
                        final t = await showTimePicker(context: ctx, initialTime: end);
                        if (t != null) setD(() => end = t);
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.logout_rounded, size: 16, color: KColors.error),
                          KSpacing.hGapSm,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('End Time', style: KTypography.labelSmall),
                                Text(end.format(ctx), style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  KSpacing.vGapSm,
                  KTextField(
                    controller: offs,
                    label: 'Weekly Off Days',
                    hint: 'Comma-separated, e.g. SAT,SUN or SUN',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            KButton.primary(
              label: 'Create Shift',
              icon: Icons.check_rounded,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    if (ok != true || code.text.trim().isEmpty || name.text.trim().isEmpty) return;

    try {
      await ref.read(apiClientProvider).post(ApiConfig.hrShifts, data: {
        'code': code.text.trim().toUpperCase(),
        'name': name.text.trim(),
        'startTime': _hms(start),
        'endTime': _hms(end),
        'weeklyOffs': offs.text.trim(),
        'active': true,
      });
      _toast('Shift defined successfully');
      await _load();
    } catch (e) {
      _toast('Create failed: ${ApiErrorParser.message(e)}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Shifts & Schedules'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: KLoading(message: 'Loading shift schedules...'))
          : ListView(
              padding: KSpacing.pagePadding,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shift Roster Definitions',
                            style: KTypography.h2.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Configure working hours, weekly off rules, and attendance window parameters.',
                            style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    KButton.primary(
                      label: 'Define Shift',
                      icon: Icons.add_rounded,
                      onPressed: _create,
                    ),
                  ],
                ),
                KSpacing.vGapMd,
                if (_shifts.isEmpty)
                  const KEmptyState(
                    icon: Icons.schedule_outlined,
                    title: 'No Work Shifts Defined',
                    subtitle: 'Define work shifts to manage employee schedules and attendance rosters.',
                  )
                else
                  ..._shifts.map((s) {
                    final active = s['active'] == true;
                    return KCard(
                      margin: const EdgeInsets.only(bottom: KSpacing.sm),
                      padding: const EdgeInsets.all(KSpacing.md),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(KSpacing.radiusMd),
                            ),
                            child: Icon(Icons.access_time_rounded, color: cs.primary, size: 20),
                          ),
                          KSpacing.hGapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${s['name']}',
                                      style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    KSpacing.hGapSm,
                                    Text(
                                      '(${s['code']})',
                                      style: KTypography.mono(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Timing: ${s['startTime']} – ${s['endTime']}  •  Weekly Offs: ${s['weeklyOffs'] ?? 'None'}',
                                  style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          KStatusChip(status: active ? 'ACTIVE' : 'INACTIVE'),
                        ],
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
