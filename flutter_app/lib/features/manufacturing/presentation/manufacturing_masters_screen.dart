import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/routing_repository.dart';

/// Workstations + Operations masters — the building blocks every routing
/// references. Until now they could only be created by knowing their UUIDs;
/// this gives them a CRUD surface so routings can actually be built.
class ManufacturingMastersScreen extends ConsumerWidget {
  const ManufacturingMastersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Workstations & Operations'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Workstations'),
              Tab(text: 'Operations'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _WorkstationsTab(),
            _OperationsTab(),
          ],
        ),
      ),
    );
  }
}

// ── Workstations ─────────────────────────────────────────────────────────────

class _WorkstationsTab extends ConsumerWidget {
  const _WorkstationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workstationsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'ws',
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New workstation'),
      ),
      body: async.when(
        loading: () => const KLoading(),
        error: (e, _) => KErrorView(
          message: 'Failed to load workstations',
          onRetry: () => ref.invalidate(workstationsProvider),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return KEmptyState(
              icon: Icons.precision_manufacturing_outlined,
              title: 'No workstations',
              subtitle:
                  'A workstation is a machine or work centre. Operations and '
                  'routings reference them.',
              actionLabel: 'New workstation',
              onAction: () => _create(context, ref),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(workstationsProvider),
            child: ListView.separated(
              padding: KSpacing.pagePadding,
              itemCount: rows.length,
              separatorBuilder: (_, __) => KSpacing.vGapSm,
              itemBuilder: (_, i) {
                final w = rows[i];
                final rate = (w['hourlyRate'] as num?)?.toDouble();
                final cap = (w['capacityHoursPerDay'] as num?)?.toDouble();
                return KCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(w['code']?.toString() ?? '',
                                    style: KTypography.mono(size: 13)),
                                KSpacing.hGapSm,
                                Expanded(
                                  child: Text(w['name']?.toString() ?? '',
                                      style: KTypography.labelLarge,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                            KSpacing.vGapXs,
                            Text(
                              [
                                if (rate != null) '₹$rate/hr',
                                if (cap != null) '$cap h/day capacity',
                              ].join(' · '),
                              style: KTypography.bodySmall
                                  .copyWith(color: KColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (w['isActive'] == false)
                        KStatusChip(status: 'Inactive'),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final codeCtl = TextEditingController();
    final nameCtl = TextEditingController();
    final descCtl = TextEditingController();
    final rateCtl = TextEditingController();
    final capCtl = TextEditingController(text: '8');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New workstation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(codeCtl, 'Code'),
              _field(nameCtl, 'Name'),
              _field(descCtl, 'Description (optional)'),
              _field(rateCtl, 'Hourly rate ₹ (optional)', number: true),
              _field(capCtl, 'Capacity hours/day', number: true),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create')),
        ],
      ),
    );
    if (ok != true) return;
    if (codeCtl.text.trim().isEmpty || nameCtl.text.trim().isEmpty) {
      _toast(context, 'Code and name are required');
      return;
    }
    try {
      await ref.read(routingRepositoryProvider).createWorkstation(
            code: codeCtl.text.trim(),
            name: nameCtl.text.trim(),
            description: descCtl.text.trim(),
            hourlyRate: double.tryParse(rateCtl.text.trim()),
            capacityHours: double.tryParse(capCtl.text.trim()),
          );
      ref.invalidate(workstationsProvider);
      _toast(context, 'Workstation created');
    } catch (e) {
      _toast(context,
          'Could not create: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }
}

// ── Operations ───────────────────────────────────────────────────────────────

class _OperationsTab extends ConsumerWidget {
  const _OperationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(operationsProvider);
    final workstations = ref.watch(workstationsProvider).valueOrNull ?? const [];
    String wsName(String? id) {
      if (id == null) return '';
      final w = workstations.firstWhere((e) => e['id']?.toString() == id,
          orElse: () => const {});
      return w['name']?.toString() ?? '';
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'op',
        onPressed: () => _create(context, ref, workstations),
        icon: const Icon(Icons.add),
        label: const Text('New operation'),
      ),
      body: async.when(
        loading: () => const KLoading(),
        error: (e, _) => KErrorView(
          message: 'Failed to load operations',
          onRetry: () => ref.invalidate(operationsProvider),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return KEmptyState(
              icon: Icons.build_circle_outlined,
              title: 'No operations',
              subtitle:
                  'An operation is a production step (cutting, mixing, packing). '
                  'Routings order them into a process.',
              actionLabel: 'New operation',
              onAction: () => _create(context, ref, workstations),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(operationsProvider),
            child: ListView.separated(
              padding: KSpacing.pagePadding,
              itemCount: rows.length,
              separatorBuilder: (_, __) => KSpacing.vGapSm,
              itemBuilder: (_, i) {
                final o = rows[i];
                final setup = (o['setupTimeMinutes'] as num?)?.toInt();
                final run = (o['runTimeMinutesPerUnit'] as num?)?.toDouble();
                final ws = wsName(o['defaultWorkstationId']?.toString());
                return KCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(o['code']?.toString() ?? '',
                              style: KTypography.mono(size: 13)),
                          KSpacing.hGapSm,
                          Expanded(
                            child: Text(o['name']?.toString() ?? '',
                                style: KTypography.labelLarge,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      KSpacing.vGapXs,
                      Text(
                        [
                          if (setup != null) 'setup ${setup}m',
                          if (run != null) 'run ${run}m/unit',
                          if (ws.isNotEmpty) 'on $ws',
                        ].join(' · '),
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref,
      List<dynamic> workstations) async {
    final codeCtl = TextEditingController();
    final nameCtl = TextEditingController();
    final descCtl = TextEditingController();
    final setupCtl = TextEditingController(text: '0');
    final runCtl = TextEditingController(text: '0');
    String? wsId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New operation'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(codeCtl, 'Code'),
                _field(nameCtl, 'Name'),
                _field(descCtl, 'Description (optional)'),
                KSpacing.vGapSm,
                DropdownButtonFormField<String>(
                  initialValue: wsId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Default workstation (optional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: workstations.map((w) {
                    final m = Map<String, dynamic>.from(w as Map);
                    return DropdownMenuItem(
                      value: m['id']?.toString(),
                      child: Text(m['name']?.toString() ?? '',
                          overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) => setLocal(() => wsId = v),
                ),
                _field(setupCtl, 'Setup time (minutes)', number: true),
                _field(runCtl, 'Run time (minutes/unit)', number: true),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Create')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (codeCtl.text.trim().isEmpty || nameCtl.text.trim().isEmpty) {
      _toast(context, 'Code and name are required');
      return;
    }
    try {
      await ref.read(routingRepositoryProvider).createOperation(
            code: codeCtl.text.trim(),
            name: nameCtl.text.trim(),
            description: descCtl.text.trim(),
            defaultWorkstationId: wsId,
            setupTimeMinutes: int.tryParse(setupCtl.text.trim()),
            runTimePerUnit: double.tryParse(runCtl.text.trim()),
          );
      ref.invalidate(operationsProvider);
      _toast(context, 'Operation created');
    } catch (e) {
      _toast(context,
          'Could not create: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }
}

// ── Shared helpers ───────────────────────────────────────────────────────────

Widget _field(TextEditingController ctl, String label, {bool number = false}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: KSpacing.sm),
    child: TextField(
      controller: ctl,
      keyboardType:
          number ? const TextInputType.numberWithOptions(decimal: true) : null,
      inputFormatters: number
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
          : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
