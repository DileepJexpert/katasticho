import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';

/// Pharma Batch Manufacturing Record (BMR) viewer + editor. Paste a
/// work-order id to load the full BMR — step records, sign-offs,
/// deviations, yield reconciliation. Each tab has its own quick-add
/// dialog.
class BmrScreen extends ConsumerStatefulWidget {
  final String? initialWorkOrderId;
  const BmrScreen({super.key, this.initialWorkOrderId});

  @override
  ConsumerState<BmrScreen> createState() => _BmrScreenState();
}

class _BmrScreenState extends ConsumerState<BmrScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _woCtl = TextEditingController();
  String? _woId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    if (widget.initialWorkOrderId != null) {
      _woCtl.text = widget.initialWorkOrderId!;
      _woId = widget.initialWorkOrderId;
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _woCtl.dispose();
    super.dispose();
  }

  void _load() {
    final id = _woCtl.text.trim();
    if (id.isEmpty) return;
    setState(() => _woId = id);
  }

  Future<void> _addStepRecord() async {
    final keyCtl = TextEditingController();
    final valCtl = TextEditingController();
    final unitCtl = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Parameter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyCtl,
              decoration: const InputDecoration(
                labelText: 'Parameter (e.g. granulation_temp)',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            KSpacing.vGapSm,
            TextField(
              controller: valCtl,
              decoration: const InputDecoration(labelText: 'Value', border: OutlineInputBorder()),
            ),
            KSpacing.vGapSm,
            TextField(
              controller: unitCtl,
              decoration: const InputDecoration(labelText: 'Unit (°C, kPa…)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          KButton.outlined(
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx),
            label: 'Cancel',
          ),
          KSpacing.hGapSm,
          KButton.primary(
            size: KButtonSize.small,
            onPressed: () {
              if (keyCtl.text.trim().isNotEmpty && valCtl.text.trim().isNotEmpty) {
                Navigator.pop(ctx, {
                  'key': keyCtl.text.trim(),
                  'val': valCtl.text.trim(),
                  'unit': unitCtl.text.trim(),
                });
              }
            },
            label: 'Save',
          ),
        ],
      ),
    );
    if (result == null) return;
    try {
      await ref.read(apiClientProvider).post(ApiConfig.bmrStepRecords, data: {
        'workOrderId': _woId,
        'parameterKey': result['key'],
        'parameterValue': result['val'],
        if ((result['unit'] ?? '').isNotEmpty) 'unit': result['unit'],
      });
      _refreshAll();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _addSignoff() async {
    final roleCtl = TextEditingController(text: 'OPERATOR');
    final notesCtl = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Sign-off'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: 'OPERATOR',
              decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'OPERATOR', child: Text('Operator')),
                DropdownMenuItem(value: 'SUPERVISOR', child: Text('Supervisor')),
                DropdownMenuItem(value: 'QA', child: Text('QA')),
                DropdownMenuItem(value: 'QC', child: Text('QC')),
              ],
              onChanged: (v) {
                if (v != null) roleCtl.text = v;
              },
            ),
            KSpacing.vGapSm,
            TextField(
              controller: notesCtl,
              decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          KButton.outlined(
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx),
            label: 'Cancel',
          ),
          KSpacing.hGapSm,
          KButton.primary(
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, {
              'role': roleCtl.text.trim(),
              'notes': notesCtl.text.trim(),
            }),
            label: 'Sign',
          ),
        ],
      ),
    );
    if (result == null) return;
    try {
      await ref.read(apiClientProvider).post(ApiConfig.bmrSignoffs, data: {
        'workOrderId': _woId,
        'role': result['role'],
        if ((result['notes'] ?? '').isNotEmpty) 'notes': result['notes'],
      });
      _refreshAll();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _addDeviation() async {
    final titleCtl = TextEditingController();
    final descCtl = TextEditingController();
    String severity = 'MINOR';
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Log Deviation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: severity,
                decoration: const InputDecoration(labelText: 'Severity', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'MINOR', child: Text('Minor')),
                  DropdownMenuItem(value: 'MAJOR', child: Text('Major')),
                  DropdownMenuItem(value: 'CRITICAL', child: Text('Critical')),
                ],
                onChanged: (v) {
                  if (v != null) setSt(() => severity = v);
                },
              ),
              KSpacing.vGapSm,
              TextField(
                controller: titleCtl,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              ),
              KSpacing.vGapSm,
              TextField(
                controller: descCtl,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                minLines: 2,
                maxLines: 4,
              ),
            ],
          ),
          actions: [
            KButton.outlined(
              size: KButtonSize.small,
              onPressed: () => Navigator.pop(ctx),
              label: 'Cancel',
            ),
            KSpacing.hGapSm,
            KButton.primary(
              size: KButtonSize.small,
              onPressed: () {
                if (titleCtl.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, {
                    'severity': severity,
                    'title': titleCtl.text.trim(),
                    'description': descCtl.text.trim(),
                  });
                }
              },
              label: 'Log',
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    try {
      await ref.read(apiClientProvider).post(ApiConfig.bmrDeviations, data: {
        'workOrderId': _woId,
        'severity': result['severity'],
        'title': result['title'],
        if ((result['description'] ?? '').isNotEmpty)
          'description': result['description'],
      });
      _refreshAll();
    } catch (e) {
      _showError(e);
    }
  }

  void _refreshAll() {
    if (_woId == null) return;
    ref.invalidate(_yieldProvider(_woId!));
    ref.invalidate(_stepRecordsProvider(_woId!));
    ref.invalidate(_signoffsProvider(_woId!));
    ref.invalidate(_deviationsProvider(_woId!));
  }

  Future<void> _downloadPdf() async {
    final woId = _woId;
    if (woId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Generating BMR PDF…'), backgroundColor: KColors.info),
    );
    try {
      final res = await ref.read(apiClientProvider).get(
            ApiConfig.bmrWorkOrderPdf(woId),
            options: Options(responseType: ResponseType.bytes),
          );
      final bytes = res.data as List<int>;
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: 'BMR-$woId.pdf',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
      );
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Manufacturing Record'),
        actions: _woId == null
            ? null
            : [
                IconButton(
                  tooltip: 'Download regulator-ready BMR PDF',
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  onPressed: _downloadPdf,
                ),
              ],
        bottom: _woId == null
            ? null
            : TabBar(
                controller: _tabs,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Parameters'),
                  Tab(text: 'Sign-offs'),
                  Tab(text: 'Deviations'),
                ],
              ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(KSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _woCtl,
                    decoration: const InputDecoration(
                      labelText: 'Work Order ID',
                      helperText: 'The batch (work order) whose BMR you want to view',
                      prefixIcon: Icon(Icons.science_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                KSpacing.hGapSm,
                KButton.primary(onPressed: _load, label: 'Load'),
              ],
            ),
          ),
          Expanded(
            child: _woId == null
                ? const Center(
                    child: KEmptyState(
                      icon: Icons.science_outlined,
                      title: 'Select Work Order',
                      subtitle: 'Enter a work order ID above to load and audit its Batch Manufacturing Record.',
                    ),
                  )
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _OverviewTab(woId: _woId!),
                      _StepRecordsTab(woId: _woId!),
                      _SignoffsTab(woId: _woId!),
                      _DeviationsTab(woId: _woId!),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: _woId == null ? null : _buildFab(),
    );
  }

  Widget? _buildFab() {
    return AnimatedBuilder(
      animation: _tabs,
      builder: (ctx, _) {
        return switch (_tabs.index) {
          1 => FloatingActionButton.extended(
              backgroundColor: KColors.primary,
              foregroundColor: Colors.white,
              onPressed: _addStepRecord,
              icon: const Icon(Icons.add),
              label: const Text('Add Parameter')),
          2 => FloatingActionButton.extended(
              backgroundColor: KColors.primary,
              foregroundColor: Colors.white,
              onPressed: _addSignoff,
              icon: const Icon(Icons.draw_outlined),
              label: const Text('Add Sign-off')),
          3 => FloatingActionButton.extended(
              backgroundColor: KColors.primary,
              foregroundColor: Colors.white,
              onPressed: _addDeviation,
              icon: const Icon(Icons.warning_amber_outlined),
              label: const Text('Log Deviation')),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  final String woId;
  const _OverviewTab({required this.woId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_yieldProvider(woId));
    return async.when(
      loading: () => const Center(child: KLoading(message: 'Loading yield reconciliation...')),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (y) {
        final status = y['status']?.toString() ?? 'PENDING';
        return ListView(
          padding: KSpacing.pagePadding,
          children: [
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      KStatusChip(status: status),
                      KSpacing.hGapSm,
                      Text('Yield Reconciliation',
                          style: KTypography.titleMedium),
                    ]),
                    KSpacing.vGapMd,
                    _kv('Work Order', y['workOrderNumber']),
                    _kv('Planned Qty', y['plannedQty']),
                    _kv('Produced Qty', y['producedQty']),
                    _kv('Yield %', '${y['yieldPercent']}'),
                    _kv('Deviation %', '${y['deviationPercent']}'),
                  ],
                ),
              ),
            ),
            KSpacing.vGapMd,
            Text(
              'Use the tabs above to record parameters during each operation, '
              'capture operator/supervisor/QA sign-offs at each critical step, '
              'and log deviations from the master formula.',
              style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
            ),
          ],
        );
      },
    );
  }

  Widget _kv(String k, Object? v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(width: 120, child: Text(k, style: KTypography.bodySmall.copyWith(color: KColors.textSecondary))),
          Text('$v', style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _StepRecordsTab extends ConsumerWidget {
  final String woId;
  const _StepRecordsTab({required this.woId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_stepRecordsProvider(woId));
    return async.when(
      loading: () => const Center(child: KLoading(message: 'Loading step parameters...')),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (rows) {
        if (rows.isEmpty) {
          return const KEmptyState(
            icon: Icons.thermostat_outlined,
            title: 'No parameters recorded yet',
            subtitle: 'Add process parameters (temperature, pressure, blending duration) during operations.',
          );
        }
        return ListView.builder(
          padding: KSpacing.pagePadding,
          itemCount: rows.length,
          itemBuilder: (ctx, i) {
            final r = rows[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: KCard(
                child: ListTile(
                  leading: const Icon(Icons.thermostat_outlined, color: KColors.primary),
                  title: Text(
                    '${r['parameterKey']}: ${r['parameterValue']}${r['unit'] != null ? ' ${r['unit']}' : ''}',
                    style: KTypography.labelLarge,
                  ),
                  subtitle: Text(
                    'Observed at ${r['observedAt']}${r['notes'] != null ? '\n${r['notes']}' : ''}',
                    style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SignoffsTab extends ConsumerWidget {
  final String woId;
  const _SignoffsTab({required this.woId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_signoffsProvider(woId));
    return async.when(
      loading: () => const Center(child: KLoading(message: 'Loading sign-offs...')),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (rows) {
        if (rows.isEmpty) {
          return const KEmptyState(
            icon: Icons.draw_outlined,
            title: 'No sign-offs recorded',
            subtitle: 'Capture critical QA / QC / Supervisor step sign-offs to complete the BMR audit trail.',
          );
        }
        return ListView.builder(
          padding: KSpacing.pagePadding,
          itemCount: rows.length,
          itemBuilder: (ctx, i) {
            final r = rows[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: KCard(
                child: ListTile(
                  leading: const Icon(Icons.draw_outlined, color: KColors.success),
                  title: Text('${r['role']} sign-off', style: KTypography.labelLarge),
                  subtitle: Text(
                    'Signed at ${r['signedAt']}${r['notes'] != null ? '\n${r['notes']}' : ''}',
                    style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DeviationsTab extends ConsumerWidget {
  final String woId;
  const _DeviationsTab({required this.woId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_deviationsProvider(woId));
    return async.when(
      loading: () => const Center(child: KLoading(message: 'Loading deviations...')),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (rows) {
        if (rows.isEmpty) {
          return const KEmptyState(
            icon: Icons.check_circle_outline,
            title: 'No deviations logged',
            subtitle: 'No GMP or batch deviations were reported for this production run.',
          );
        }
        return ListView.builder(
          padding: KSpacing.pagePadding,
          itemCount: rows.length,
          itemBuilder: (ctx, i) {
            final r = rows[i];
            final severity = r['severity']?.toString() ?? 'MINOR';
            final status = r['status']?.toString() ?? 'OPEN';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: KCard(
                child: ListTile(
                  leading: const Icon(Icons.warning_amber, color: KColors.warning),
                  title: Text('[$severity] ${r['title']}', style: KTypography.labelLarge),
                  subtitle: Text(
                    'Status: $status • ${r['reportedAt']}${r['description'] != null ? '\n${r['description']}' : ''}',
                    style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                  ),
                  trailing: KStatusChip(status: status),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

final _yieldProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, woId) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get(ApiConfig.bmrWorkOrderYield(woId));
  final data = res.data['data'];
  return data is Map<String, dynamic> ? data : <String, dynamic>{};
});

final _stepRecordsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, woId) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get(ApiConfig.bmrWorkOrderStepRecords(woId));
  final data = res.data['data'];
  if (data is List) {
    return data.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }
  return [];
});

final _signoffsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, woId) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get(ApiConfig.bmrWorkOrderSignoffs(woId));
  final data = res.data['data'];
  if (data is List) {
    return data.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }
  return [];
});

final _deviationsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, woId) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get(ApiConfig.bmrWorkOrderDeviations(woId));
  final data = res.data['data'];
  if (data is List) {
    return data.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }
  return [];
});
