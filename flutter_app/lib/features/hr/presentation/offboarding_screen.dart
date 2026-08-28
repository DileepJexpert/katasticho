import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_compact_row.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';

/// HR Offboarding — Core HR module.
/// List of exits + initiate dialog + clearance checklist / F&F / complete.
class OffboardingScreen extends ConsumerStatefulWidget {
  const OffboardingScreen({super.key});

  @override
  ConsumerState<OffboardingScreen> createState() => _OffboardingScreenState();
}

class _OffboardingScreenState extends ConsumerState<OffboardingScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _list(Object? d) =>
      (d as List?)?.cast<Map<String, dynamic>>() ?? [];

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = ref.read(apiClientProvider);
    try {
      final results = await Future.wait([
        api.get(ApiConfig.hrOffboarding),
        api.get(ApiConfig.orgUsers),
      ]);
      if (!mounted) return;
      setState(() {
        _items = _list(results[0].data['data']);
        _users = _list(results[1].data['data']);
      });
    } catch (e) {
      _toast('Failed to load offboarding records: ${ApiErrorParser.message(e)}', isError: true);
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

  String _ymd(DateTime d) => d.toIso8601String().split('T').first;

  Future<void> _initiate() async {
    String? userId;
    DateTime? resignation;
    DateTime? lastDay;
    final reason = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Initiate Employee Offboarding', style: KTypography.titleLarge),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: userId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select Employee *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final u in _users)
                        DropdownMenuItem(
                          value: u['id'].toString(),
                          child: Text(u['fullName']?.toString() ?? u['id'].toString()),
                        ),
                    ],
                    onChanged: (v) => setD(() => userId = v),
                  ),
                  KSpacing.vGapSm,
                  KCompactRow(children: [
                    KCard(
                      onTap: () async {
                        final d = await showDatePicker(
                            context: ctx, initialDate: DateTime.now(),
                            firstDate: DateTime(DateTime.now().year - 1),
                            lastDate: DateTime(DateTime.now().year + 1));
                        if (d != null) setD(() => resignation = d);
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.event_note_rounded, size: 16, color: KColors.primary),
                          KSpacing.hGapSm,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Resignation Date', style: KTypography.labelSmall),
                                Text(
                                  resignation == null ? 'Select Date' : DateFormatter.display(resignation!),
                                  style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    KCard(
                      onTap: () async {
                        final d = await showDatePicker(
                            context: ctx, initialDate: DateTime.now(),
                            firstDate: DateTime(DateTime.now().year - 1),
                            lastDate: DateTime(DateTime.now().year + 1));
                        if (d != null) setD(() => lastDay = d);
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.event_available_rounded, size: 16, color: KColors.warning),
                          KSpacing.hGapSm,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Last Working Day', style: KTypography.labelSmall),
                                Text(
                                  lastDay == null ? 'Select Date' : DateFormatter.display(lastDay!),
                                  style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  KSpacing.vGapSm,
                  KTextField(
                    controller: reason,
                    label: 'Reason for Exit / Notes',
                    hint: 'e.g. Better opportunity, relocation, personal reasons',
                    maxLines: 2,
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
              icon: Icons.logout_rounded,
              label: 'Initiate Exit Process',
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    if (ok != true || userId == null) return;
    try {
      await ref.read(apiClientProvider).post(ApiConfig.hrOffboarding, data: {
        'employeeUserId': userId,
        'resignationDate': resignation == null ? null : _ymd(resignation!),
        'lastWorkingDay': lastDay == null ? null : _ymd(lastDay!),
        'reason': reason.text.trim(),
      });
      _toast('Offboarding initiated successfully');
      await _load();
    } catch (e) {
      _toast('Failed: ${ApiErrorParser.message(e)}', isError: true);
    }
  }

  Future<void> _openDetail(String id) async {
    Map<String, dynamic> ob = {};
    List<Map<String, dynamic>> tasks = [];
    try {
      final res = await ref.read(apiClientProvider).get(ApiConfig.hrOffboardingById(id));
      final data = (res.data['data'] as Map?)?.cast<String, dynamic>() ?? {};
      ob = (data['offboarding'] as Map?)?.cast<String, dynamic>() ?? {};
      tasks = _list(data['tasks']);
    } catch (e) {
      _toast('Failed: ${ApiErrorParser.message(e)}', isError: true);
      return;
    }
    if (!mounted) return;

    final status = ob['status']?.toString() ?? 'INITIATED';
    final cs = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(KSpacing.radiusLg)),
          ),
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Offboarding Exit Checklist', style: KTypography.titleLarge),
                    ),
                    KStatusChip(status: status),
                  ],
                ),
                if (ob['lastWorkingDay'] != null) ...[
                  KSpacing.vGapXs,
                  Row(
                    children: [
                      Text('Last Working Day: ', style: KTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                      Text('${ob['lastWorkingDay']}', style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
                if (ob['fnfAmount'] != null) ...[
                  KSpacing.vGapXs,
                  Row(
                    children: [
                      Text('Settled F&F Amount: ', style: KTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                      KMoney((ob['fnfAmount'] as num).toDouble(), style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
                KSpacing.vGapMd,
                const Divider(height: 1),
                KSpacing.vGapSm,
                Text('Clearance Tasks & Handover', style: KTypography.titleMedium),
                KSpacing.vGapSm,
                if (tasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No clearance tasks assigned.', style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant)),
                  )
                else
                  for (final t in tasks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: KCard(
                        padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm, vertical: KSpacing.xs),
                        child: Row(
                          children: [
                            Checkbox(
                              value: t['completed'] == true,
                              activeColor: KColors.success,
                              onChanged: (t['completed'] == true)
                                  ? null
                                  : (_) async {
                                      try {
                                        await ref.read(apiClientProvider).post(
                                            ApiConfig.hrOffboardingTaskComplete(t['id'].toString()));
                                        setS(() => t['completed'] = true);
                                      } catch (e) {
                                        _toast('Failed: ${ApiErrorParser.message(e)}', isError: true);
                                      }
                                    },
                            ),
                            KSpacing.hGapSm,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${t['label']}',
                                    style: KTypography.bodyMedium.copyWith(
                                      decoration: t['completed'] == true ? TextDecoration.lineThrough : null,
                                      color: t['completed'] == true ? cs.onSurfaceVariant : cs.onSurface,
                                    ),
                                  ),
                                  Text('${t['category']}', style: KTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            if (t['completed'] == true)
                              const Icon(Icons.check_circle_rounded, color: KColors.success, size: 18),
                          ],
                        ),
                      ),
                    ),
                KSpacing.vGapMd,
                const Divider(height: 1),
                KSpacing.vGapMd,
                Row(
                  children: [
                    KButton.outlined(
                      icon: Icons.payments_outlined,
                      label: 'Settle F&F',
                      onPressed: () => _settleFnf(ctx, id),
                    ),
                    KSpacing.hGapSm,
                    KButton.primary(
                      icon: Icons.task_alt_rounded,
                      label: 'Complete Exit',
                      onPressed: () async {
                        try {
                          await ref.read(apiClientProvider)
                              .post(ApiConfig.hrOffboardingComplete(id));
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          _toast('Cannot complete: ${ApiErrorParser.message(e)}', isError: true);
                        }
                      },
                    ),
                    const Spacer(),
                    KButton.danger(
                      size: KButtonSize.small,
                      label: 'Cancel Exit',
                      onPressed: () async {
                        try {
                          await ref.read(apiClientProvider)
                              .post(ApiConfig.hrOffboardingCancel(id));
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          _toast('Failed: ${ApiErrorParser.message(e)}', isError: true);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await _load();
  }

  Future<void> _settleFnf(BuildContext sheetCtx, String id) async {
    final amt = TextEditingController();
    final ok = await showDialog<bool>(
      context: sheetCtx,
      builder: (ctx) => AlertDialog(
        title: Text('Settle Full & Final (F&F)', style: KTypography.titleLarge),
        content: SizedBox(
          width: 360,
          child: KTextField.amount(
            controller: amt,
            label: 'Final Settlement Amount',
            hint: '0.00',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          KButton.primary(
            icon: Icons.check_rounded,
            label: 'Confirm F&F Settlement',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).post(ApiConfig.hrOffboardingFnf(id),
          data: {'amount': double.tryParse(amt.text.trim()) ?? 0});
      _toast('F&F settled successfully');
    } catch (e) {
      _toast('Failed: ${ApiErrorParser.message(e)}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Offboarding & Exit Clearance'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: KLoading(message: 'Loading offboarding records...'))
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
                            'Exit Management & Clearances',
                            style: KTypography.h2.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Track resignation notices, department clearances, and full & final (F&F) payouts.',
                            style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    KButton.primary(
                      label: 'Initiate Exit',
                      icon: Icons.logout_rounded,
                      onPressed: _initiate,
                    ),
                  ],
                ),
                KSpacing.vGapMd,
                if (_items.isEmpty)
                  const KEmptyState(
                    icon: Icons.person_off_outlined,
                    title: 'No Active Offboarding Cases',
                    subtitle: 'No employee exits or clearance checklists currently in progress.',
                  )
                else
                  ..._items.map((o) {
                    final status = o['status']?.toString() ?? 'INITIATED';
                    final lwd = o['lastWorkingDay']?.toString();
                    final empName = o['employeeName']?.toString();
                    final idStr = o['id'].toString();
                    final shortId = idStr.length > 8 ? idStr.substring(0, 8) : idStr;

                    return KCard(
                      margin: const EdgeInsets.only(bottom: KSpacing.sm),
                      padding: const EdgeInsets.all(KSpacing.md),
                      onTap: () => _openDetail(idStr),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: KColors.error.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(KSpacing.radiusMd),
                            ),
                            child: const Icon(Icons.logout_rounded, color: KColors.error, size: 20),
                          ),
                          KSpacing.hGapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      empName ?? 'Exit Case #$shortId',
                                      style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    if (lwd != null) ...[
                                      KSpacing.hGapSm,
                                      Text('LWD: $lwd', style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                                    ],
                                  ],
                                ),
                                if (o['reason'] != null && o['reason'].toString().isNotEmpty) ...[
                                  KSpacing.vGapXs,
                                  Text(
                                    o['reason'].toString(),
                                    style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          KStatusChip(status: status),
                          KSpacing.hGapSm,
                          Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                        ],
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
