import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../inventory/presentation/item_picker_sheet.dart';
import '../data/qc_repository.dart';

/// Non-Conformance Reports — the quality issues raised against failed QC
/// inspections (or manually). Walk them OPEN → IN_PROGRESS → CLOSED with a
/// corrective action + root cause. A QC REJECT disposition auto-opens one.
class NcrListScreen extends ConsumerStatefulWidget {
  const NcrListScreen({super.key});

  @override
  ConsumerState<NcrListScreen> createState() => _NcrListScreenState();
}

class _NcrListScreenState extends ConsumerState<NcrListScreen> {
  String _status = ''; // '' = all
  static const _filters = ['', 'OPEN', 'IN_PROGRESS', 'CLOSED'];
  static const _severities = ['MINOR', 'MAJOR', 'CRITICAL'];

  QcRepository get _repo => ref.read(qcRepositoryProvider);

  void _refresh() => ref.invalidate(ncrsProvider(_status));

  @override
  Widget build(BuildContext context) {
    final ncrsAsync = ref.watch(ncrsProvider(_status));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Non-Conformance Reports'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
              children: _filters.map((f) {
                return Padding(
                  padding: const EdgeInsets.only(right: KSpacing.sm),
                  child: ChoiceChip(
                    label: Text(f.isEmpty ? 'All' : f.replaceAll('_', ' ')),
                    selected: _status == f,
                    onSelected: (_) => setState(() => _status = f),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _raiseNcr,
        icon: const Icon(Icons.add),
        label: const Text('Raise NCR'),
      ),
      body: ncrsAsync.when(
        loading: () => const KLoading(),
        error: (e, _) => KErrorView(
          message: 'Failed to load NCRs',
          onRetry: _refresh,
        ),
        data: (ncrs) {
          if (ncrs.isEmpty) {
            return KEmptyState(
              icon: Icons.report_problem_outlined,
              title: _status.isEmpty
                  ? 'No non-conformance reports'
                  : 'No ${_status.replaceAll('_', ' ').toLowerCase()} NCRs',
              subtitle:
                  'NCRs capture quality issues from failed inspections. A QC '
                  'REJECT disposition opens one automatically; you can also '
                  'raise one manually.',
              actionLabel: 'Raise NCR',
              onAction: _raiseNcr,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: KSpacing.pagePadding,
              itemCount: ncrs.length,
              separatorBuilder: (_, __) => KSpacing.vGapSm,
              itemBuilder: (_, i) => _ncrCard(ncrs[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _ncrCard(Map<String, dynamic> n) {
    final severity = n['severity']?.toString() ?? 'MAJOR';
    final status = n['status']?.toString() ?? 'OPEN';
    final sevColor = switch (severity) {
      'CRITICAL' => KColors.error,
      'MAJOR' => KColors.warning,
      _ => KColors.textSecondary,
    };
    return InkWell(
      onTap: () => _editNcr(n),
      borderRadius: KSpacing.borderRadiusMd,
      child: KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(n['ncrNumber']?.toString() ?? 'NCR',
                      style: KTypography.labelLarge),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: sevColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(severity,
                      style:
                          KTypography.labelSmall.copyWith(color: sevColor)),
                ),
                KSpacing.hGapSm,
                KStatusChip(status: status.replaceAll('_', ' ')),
              ],
            ),
            KSpacing.vGapXs,
            Text(n['reason']?.toString() ?? '',
                style: KTypography.bodyMedium),
            if ((n['batchNumber']?.toString() ?? '').isNotEmpty) ...[
              KSpacing.vGapXs,
              Text('Batch ${n['batchNumber']}',
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Raise ────────────────────────────────────────────────────────────

  Future<void> _raiseNcr() async {
    String? itemId;
    String? itemName;
    String severity = 'MAJOR';
    final batchCtl = TextEditingController();
    final reasonCtl = TextEditingController();
    final descCtl = TextEditingController();

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
            left: KSpacing.lg,
            right: KSpacing.lg,
            top: KSpacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + KSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Raise NCR', style: KTypography.h3),
                KSpacing.vGapMd,
                OutlinedButton.icon(
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: Text(itemName ?? 'Pick item'),
                  onPressed: () async {
                    final item = await showItemPicker(ctx);
                    if (item != null) {
                      setLocal(() {
                        itemId = item['id']?.toString();
                        itemName = item['name']?.toString() ??
                            item['sku']?.toString();
                      });
                    }
                  },
                ),
                KSpacing.vGapMd,
                DropdownButtonFormField<String>(
                  initialValue: severity,
                  decoration: const InputDecoration(
                      labelText: 'Severity', border: OutlineInputBorder()),
                  items: _severities
                      .map((s) =>
                          DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setLocal(() => severity = v ?? severity),
                ),
                KSpacing.vGapMd,
                TextField(
                  controller: reasonCtl,
                  decoration: const InputDecoration(
                      labelText: 'Reason', border: OutlineInputBorder()),
                ),
                KSpacing.vGapMd,
                TextField(
                  controller: batchCtl,
                  decoration: const InputDecoration(
                      labelText: 'Batch number (optional)',
                      border: OutlineInputBorder()),
                ),
                KSpacing.vGapMd,
                TextField(
                  controller: descCtl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder()),
                ),
                KSpacing.vGapLg,
                KButton(
                  label: 'Raise NCR',
                  icon: Icons.check,
                  onPressed: () async {
                    if (itemId == null) {
                      _toast('Pick an item');
                      return;
                    }
                    if (reasonCtl.text.trim().isEmpty) {
                      _toast('Enter a reason');
                      return;
                    }
                    try {
                      await _repo.createNcr(
                        itemId: itemId!,
                        batchNumber: batchCtl.text.trim(),
                        severity: severity,
                        reason: reasonCtl.text.trim(),
                        description: descCtl.text.trim(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      _toast(
                          'Could not raise: ${e.toString().replaceAll('Exception: ', '')}');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (created == true) {
      _toast('NCR raised');
      _refresh();
    }
  }

  // ── Edit / work an NCR ───────────────────────────────────────────────

  Future<void> _editNcr(Map<String, dynamic> n) async {
    final id = n['id'].toString();
    final isClosed = (n['status']?.toString() ?? '') == 'CLOSED';
    String status = n['status']?.toString() ?? 'OPEN';
    final correctiveCtl =
        TextEditingController(text: n['correctiveAction']?.toString() ?? '');
    final rootCauseCtl =
        TextEditingController(text: n['rootCause']?.toString() ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
            left: KSpacing.lg,
            right: KSpacing.lg,
            top: KSpacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + KSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${n['ncrNumber']} · ${n['severity']}',
                    style: KTypography.h3),
                KSpacing.vGapXs,
                Text(n['reason']?.toString() ?? '',
                    style: KTypography.bodyMedium
                        .copyWith(color: KColors.textSecondary)),
                KSpacing.vGapMd,
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(
                      labelText: 'Status', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'OPEN', child: Text('Open')),
                    DropdownMenuItem(
                        value: 'IN_PROGRESS', child: Text('In progress')),
                    DropdownMenuItem(value: 'CLOSED', child: Text('Closed')),
                  ],
                  onChanged: isClosed
                      ? null
                      : (v) => setLocal(() => status = v ?? status),
                ),
                KSpacing.vGapMd,
                TextField(
                  controller: rootCauseCtl,
                  enabled: !isClosed,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Root cause', border: OutlineInputBorder()),
                ),
                KSpacing.vGapMd,
                TextField(
                  controller: correctiveCtl,
                  enabled: !isClosed,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Corrective action',
                      border: OutlineInputBorder()),
                ),
                KSpacing.vGapLg,
                if (!isClosed)
                  Row(
                    children: [
                      Expanded(
                        child: KButton(
                          label: 'Save',
                          icon: Icons.save_outlined,
                          variant: KButtonVariant.outlined,
                          onPressed: () async {
                            try {
                              await _repo.updateNcr(
                                id,
                                correctiveAction: correctiveCtl.text.trim(),
                                rootCause: rootCauseCtl.text.trim(),
                                status: status,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              _refresh();
                            } catch (e) {
                              _toast('Could not save: $e');
                            }
                          },
                        ),
                      ),
                      KSpacing.hGapMd,
                      Expanded(
                        child: KButton(
                          label: 'Close NCR',
                          icon: Icons.check_circle_outline,
                          onPressed: () async {
                            try {
                              await _repo.closeNcr(id);
                              if (ctx.mounted) Navigator.pop(ctx);
                              _refresh();
                              _toast('NCR closed');
                            } catch (e) {
                              _toast(
                                  'Could not close: ${e.toString().replaceAll('Exception: ', '')}');
                            }
                          },
                        ),
                      ),
                    ],
                  )
                else
                  Text('This NCR is closed.',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.success)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
