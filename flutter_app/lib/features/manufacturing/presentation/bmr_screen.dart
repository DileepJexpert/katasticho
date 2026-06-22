import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';

/// Pharma Batch Manufacturing Record (BMR) viewer + editor. Paste a
/// work-order id to load the full BMR — step records, sign-offs,
/// deviations, yield reconciliation. Each tab has its own quick-add
/// dialog.
///
/// This is the document a Schedule M / WHO-GMP regulator's audit
/// trail consumes. The PDF generator (separate piece, not in this
/// commit) would consume the same snapshot endpoint.
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
        title: const Text('Record parameter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyCtl,
              decoration: const InputDecoration(
                labelText: 'Parameter (e.g. granulation_temp)'),
              autofocus: true,
            ),
            TextField(
              controller: valCtl,
              decoration: const InputDecoration(labelText: 'Value'),
            ),
            TextField(
              controller: unitCtl,
              decoration: const InputDecoration(labelText: 'Unit (°C, kPa…)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (keyCtl.text.trim().isNotEmpty && valCtl.text.trim().isNotEmpty) {
                Navigator.pop(ctx, {
                  'key': keyCtl.text.trim(),
                  'val': valCtl.text.trim(),
                  'unit': unitCtl.text.trim(),
                });
              }
            },
            child: const Text('Save'),
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
        title: const Text('Add sign-off'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: 'OPERATOR',
              decoration: const InputDecoration(labelText: 'Role'),
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
            TextField(
              controller: notesCtl,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {
              'role': roleCtl.text.trim(),
              'notes': notesCtl.text.trim(),
            }),
            child: const Text('Sign'),
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
          title: const Text('Log deviation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: severity,
                decoration: const InputDecoration(labelText: 'Severity'),
                items: const [
                  DropdownMenuItem(value: 'MINOR', child: Text('Minor')),
                  DropdownMenuItem(value: 'MAJOR', child: Text('Major')),
                  DropdownMenuItem(value: 'CRITICAL', child: Text('Critical')),
                ],
                onChanged: (v) {
                  if (v != null) setSt(() => severity = v);
                },
              ),
              TextField(
                controller: titleCtl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: descCtl,
                decoration: const InputDecoration(labelText: 'Description'),
                minLines: 2,
                maxLines: 4,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (titleCtl.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, {
                    'severity': severity,
                    'title': titleCtl.text.trim(),
                    'description': descCtl.text.trim(),
                  });
                }
              },
              child: const Text('Log'),
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

  /// Pulls the regulator-ready BMR PDF from the server and pops it
  /// through the native share/save sheet (or print preview on
  /// desktop). Uses the existing Dio client so the bearer token is
  /// attached automatically.
  Future<void> _downloadPdf() async {
    final woId = _woId;
    if (woId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Generating BMR PDF…')),
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
        SnackBar(content: Text(ApiErrorParser.message(e))),
      );
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ApiErrorParser.message(e))),
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
                      labelText: 'Work order id',
                      helperText: 'The batch (work order) whose BMR you want to view',
                      prefixIcon: Icon(Icons.science_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                FilledButton(onPressed: _load, child: const Text('Load')),
              ],
            ),
          ),
          Expanded(
            child: _woId == null
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.science_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: KSpacing.md),
                        Text('Enter a work-order id to load its BMR'),
                      ],
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
              onPressed: _addStepRecord,
              icon: const Icon(Icons.add),
              label: const Text('Add parameter')),
          2 => FloatingActionButton.extended(
              onPressed: _addSignoff,
              icon: const Icon(Icons.draw_outlined),
              label: const Text('Add sign-off')),
          3 => FloatingActionButton.extended(
              onPressed: _addDeviation,
              icon: const Icon(Icons.warning_amber_outlined),
              label: const Text('Log deviation')),
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (y) {
        final status = y['status']?.toString() ?? 'PENDING';
        final Color color = switch (status) {
          'WITHIN_TOLERANCE' => Colors.green,
          'OUT_OF_TOLERANCE' => Colors.red,
          _ => Colors.amber,
        };
        return ListView(
          padding: KSpacing.pagePadding,
          children: [
            Card(
              color: color.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.verified_outlined, color: color),
                      const SizedBox(width: 8),
                      Text('Yield: $status',
                          style: KTypography.titleMedium.copyWith(color: color)),
                    ]),
                    const SizedBox(height: 12),
                    _kv('Work order', y['workOrderNumber']),
                    _kv('Planned qty', y['plannedQty']),
                    _kv('Produced qty', y['producedQty']),
                    _kv('Yield %', '${y['yieldPercent']}'),
                    _kv('Deviation %', '${y['deviationPercent']}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: KSpacing.md),
            const Text(
              'Use the tabs above to record parameters during each operation, '
              'capture operator/supervisor/QA sign-offs at each critical step, '
              'and log deviations from the master formula.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        );
      },
    );
  }

  Widget _kv(String k, Object? v) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          SizedBox(width: 110, child: Text(k, style: KTypography.bodySmall)),
          Text('$v', style: KTypography.bodyMedium),
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(child: Text('No parameters recorded yet'));
        }
        return ListView.builder(
          padding: KSpacing.pagePadding,
          itemCount: rows.length,
          itemBuilder: (ctx, i) {
            final r = rows[i];
            return Card(
              margin: const EdgeInsets.only(bottom: KSpacing.sm),
              child: ListTile(
                leading: const Icon(Icons.thermostat_outlined),
                title: Text('${r['parameterKey']}: ${r['parameterValue']}'
                    '${r['unit'] != null ? ' ${r['unit']}' : ''}'),
                subtitle: Text(
                  'Observed at ${r['observedAt']}'
                  '${r['notes'] != null ? '\n${r['notes']}' : ''}',
                  style: KTypography.bodySmall,
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(child: Text('No sign-offs yet'));
        }
        return ListView.builder(
          padding: KSpacing.pagePadding,
          itemCount: rows.length,
          itemBuilder: (ctx, i) {
            final r = rows[i];
            return Card(
              margin: const EdgeInsets.only(bottom: KSpacing.sm),
              child: ListTile(
                leading: const Icon(Icons.draw_outlined),
                title: Text('${r['role']} sign-off'),
                subtitle: Text('Signed at ${r['signedAt']}'
                    '${r['notes'] != null ? '\n${r['notes']}' : ''}'),
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(child: Text('No deviations logged'));
        }
        return ListView.builder(
          padding: KSpacing.pagePadding,
          itemCount: rows.length,
          itemBuilder: (ctx, i) {
            final r = rows[i];
            final severity = r['severity']?.toString() ?? 'MINOR';
            final color = switch (severity) {
              'CRITICAL' => Colors.red,
              'MAJOR' => Colors.orange,
              _ => Colors.amber,
            };
            final status = r['status']?.toString() ?? 'OPEN';
            return Card(
              margin: const EdgeInsets.only(bottom: KSpacing.sm),
              child: ListTile(
                leading: Icon(Icons.warning_amber, color: color),
                title: Text('[$severity] ${r['title']}'),
                subtitle: Text(
                  'Status: $status • ${r['reportedAt']}'
                  '${r['description'] != null ? '\n${r['description']}' : ''}',
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
