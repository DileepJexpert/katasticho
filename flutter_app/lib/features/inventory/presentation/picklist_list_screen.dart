import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';

// ── Providers ──────────────────────────────────────────────────────────

final _picklistFilterProvider =
    StateProvider<_PicklistFilter>((ref) => const _PicklistFilter());

final _picklistListProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final filter = ref.watch(_picklistFilterProvider);
  final params = <String, dynamic>{
    'page': filter.page,
    'size': 25,
  };
  if (filter.status != null) params['status'] = filter.status;
  if (filter.search != null && filter.search!.isNotEmpty) {
    params['search'] = filter.search;
  }
  final response =
      await api.get(ApiConfig.picklists, queryParameters: params);
  return response.data is Map<String, dynamic>
      ? response.data as Map<String, dynamic>
      : <String, dynamic>{};
});

class _PicklistFilter {
  final String? status;
  final String? search;
  final int page;

  const _PicklistFilter({this.status, this.search, this.page = 0});

  _PicklistFilter copyWith({String? status, String? search, int? page}) =>
      _PicklistFilter(
        status: status,
        search: search ?? this.search,
        page: page ?? this.page,
      );
}

// ── Status Tabs ────────────────────────────────────────────────────────

const _statusTabs = [
  KListTab(label: 'All'),
  KListTab(label: 'Pending', value: 'PENDING'),
  KListTab(label: 'In Progress', value: 'IN_PROGRESS'),
  KListTab(label: 'Completed', value: 'COMPLETED'),
  KListTab(label: 'Cancelled', value: 'CANCELLED'),
];

// ── Screen ─────────────────────────────────────────────────────────────

class PicklistListScreen extends ConsumerStatefulWidget {
  const PicklistListScreen({super.key});

  @override
  ConsumerState<PicklistListScreen> createState() => _PicklistListScreenState();
}

class _PicklistListScreenState extends ConsumerState<PicklistListScreen> {
  String? _expandedId;
  bool _actionInProgress = false;

  Future<void> _startPicklist(String id) async {
    setState(() => _actionInProgress = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(ApiConfig.startPicklist(id));
      if (!mounted) return;
      ref.invalidate(_picklistListProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Picklist started'),
          backgroundColor: KColors.info,
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = _extractError(e, 'Failed to start picklist');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: KColors.error),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _completePicklist(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Picklist'),
        content:
            const Text('Mark this picklist as completed? Ensure all items have been picked.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _actionInProgress = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(ApiConfig.completePicklist(id));
      if (!mounted) return;
      ref.invalidate(_picklistListProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Picklist completed'),
          backgroundColor: KColors.success,
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = _extractError(e, 'Failed to complete picklist');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: KColors.error),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _cancelPicklist(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Picklist'),
        content: const Text('Cancel this picklist? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: KColors.error.withValues(alpha: 0.12),
              foregroundColor: KColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Picklist'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _actionInProgress = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(ApiConfig.cancelPicklist(id));
      if (!mounted) return;
      ref.invalidate(_picklistListProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Picklist cancelled'),
          backgroundColor: KColors.warning,
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = _extractError(e, 'Failed to cancel picklist');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: KColors.error),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _createPicklist() async {
    final soNumberCtl = TextEditingController();
    final notesCtl = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Picklist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: soNumberCtl,
              decoration: const InputDecoration(
                labelText: 'Sales Order ID',
                hintText: 'Enter sales order ID',
              ),
            ),
            KSpacing.vGapSm,
            TextField(
              controller: notesCtl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Pick instructions or notes',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (soNumberCtl.text.trim().isEmpty) return;
              Navigator.pop(ctx, {
                'salesOrderId': soNumberCtl.text.trim(),
                'notes': notesCtl.text.trim(),
              });
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _actionInProgress = true);
    try {
      final api = ref.read(apiClientProvider);
      final body = <String, dynamic>{
        'salesOrderId': result['salesOrderId'],
      };
      if (result['notes']!.isNotEmpty) body['notes'] = result['notes'];
      await api.post(ApiConfig.picklists, data: body);
      if (!mounted) return;
      ref.invalidate(_picklistListProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Picklist created'),
          backgroundColor: KColors.success,
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = _extractError(e, 'Failed to create picklist');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: KColors.error),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(_picklistFilterProvider);
    final picklistsAsync = ref.watch(_picklistListProvider);

    return KKeyboardListWrapper(
      itemCount: () {
        final raw = picklistsAsync.valueOrNull;
        if (raw == null) return 0;
        final data = raw['data'] ?? raw;
        final picklists = (data is List)
            ? data
            : (data is Map ? (data['content'] as List?) ?? [] : []);
        return picklists.length;
      },
      onNew: _actionInProgress ? null : _createPicklist,
      onRefresh: () => ref.invalidate(_picklistListProvider),
      child: Scaffold(
        body: Column(
          children: [
            KListPageHeader(
              title: 'Picklists',
              searchHint: 'Search picklists...',
              tabs: _statusTabs,
              selectedTab: filter.status,
              onTabChanged: (v) => ref
                  .read(_picklistFilterProvider.notifier)
                  .state = filter.copyWith(status: v, page: 0),
              onSearchChanged: (q) => ref
                  .read(_picklistFilterProvider.notifier)
                  .state =
                  filter.copyWith(search: q.isEmpty ? null : q, page: 0),
            ),
            Expanded(
              child: picklistsAsync.when(
                loading: () => const KShimmerList(),
                error: (err, _) => KErrorView(
                  message: 'Failed to load picklists',
                  onRetry: () => ref.invalidate(_picklistListProvider),
                ),
                data: (raw) {
                  final data = raw['data'] ?? raw;
                  final picklists = (data is List)
                      ? data
                      : (data is Map
                          ? (data['content'] as List?) ?? []
                          : []);

                  if (picklists.isEmpty) {
                    return KEmptyState(
                      icon: Icons.checklist_outlined,
                      title: filter.status != null
                          ? 'No ${_statusLabel(filter.status!).toLowerCase()} picklists'
                          : 'No picklists yet',
                      subtitle: filter.status != null
                          ? 'Try a different status filter'
                          : 'Create a picklist from a sales order to start picking',
                      actionLabel: filter.status == null ? 'Create Picklist' : null,
                      onAction: filter.status == null ? _createPicklist : null,
                    );
                  }

                  final picklistMaps = picklists
                      .whereType<Map>()
                      .map((p) => p.cast<String, dynamic>())
                      .toList();

                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(_picklistListProvider),
                    child: ListView.separated(
                      padding: KSpacing.pagePadding,
                      itemCount: picklistMaps.length,
                      separatorBuilder: (_, __) => KSpacing.vGapSm,
                      itemBuilder: (context, index) {
                        final picklist = picklistMaps[index];
                        final id = picklist['id']?.toString() ?? '';
                        final isExpanded = _expandedId == id;

                        return _PicklistCard(
                          picklist: picklist,
                          isExpanded: isExpanded,
                          actionInProgress: _actionInProgress,
                          onTap: () => setState(() =>
                              _expandedId = isExpanded ? null : id),
                          onStart: () => _startPicklist(id),
                          onComplete: () => _completePicklist(id),
                          onCancel: () => _cancelPicklist(id),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _actionInProgress ? null : _createPicklist,
          icon: const Icon(Icons.add),
          label: const Text('New Picklist'),
          tooltip: 'New Picklist (N)',
        ),
      ),
    );
  }
}

// ── Picklist Card ──────────────────────────────────────────────────────

class _PicklistCard extends StatelessWidget {
  final Map<String, dynamic> picklist;
  final bool isExpanded;
  final bool actionInProgress;
  final VoidCallback onTap;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  const _PicklistCard({
    required this.picklist,
    required this.isExpanded,
    required this.actionInProgress,
    required this.onTap,
    required this.onStart,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final picklistNumber =
        picklist['picklistNumber']?.toString() ?? '--';
    final soNumber =
        picklist['salesOrderNumber']?.toString() ?? '--';
    final warehouseName =
        picklist['warehouseName']?.toString() ?? 'Default';
    final status = picklist['status']?.toString() ?? 'PENDING';
    final assignedTo = picklist['assignedTo']?.toString();
    final notes = picklist['notes']?.toString();
    final lineCount = (picklist['lineCount'] as num?)?.toInt() ?? 0;
    final pickedCount = (picklist['pickedCount'] as num?)?.toInt() ?? 0;
    final createdAt = picklist['createdAt']?.toString();
    final startedAt = picklist['startedAt']?.toString();
    final completedAt = picklist['completedAt']?.toString();
    final lines = picklist['lines'] as List?;

    final progress = lineCount > 0 ? pickedCount / lineCount : 0.0;
    final statusChipStatus = _mapStatusToChipStatus(status);

    return KCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: picklist number + status chip
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _statusIconBg(status),
                  borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                ),
                child: Icon(
                  _statusIcon(status),
                  size: 18,
                  color: _statusIconColor(status),
                ),
              ),
              KSpacing.hGapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(picklistNumber, style: KTypography.labelLarge),
                    KSpacing.vGapXxs,
                    Text(
                      'SO: $soNumber',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary),
                    ),
                  ],
                ),
              ),
              KStatusChip(status: statusChipStatus, label: _statusLabel(status)),
            ],
          ),

          KSpacing.vGapSm,

          // Warehouse + assigned
          Row(
            children: [
              const Icon(Icons.warehouse_outlined,
                  size: 14, color: KColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                warehouseName,
                style: KTypography.bodySmall
                    .copyWith(color: KColors.textSecondary),
              ),
              if (assignedTo != null && assignedTo.isNotEmpty) ...[
                const SizedBox(width: 12),
                const Icon(Icons.person_outline,
                    size: 14, color: KColors.textSecondary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    assignedTo,
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),

          KSpacing.vGapSm,

          // Progress bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$pickedCount / $lineCount picked',
                          style: KTypography.labelSmall.copyWith(
                            color: _progressColor(status, progress),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: KTypography.labelSmall.copyWith(
                            color: _progressColor(status, progress),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    KSpacing.vGapXxs,
                    ClipRRect(
                      borderRadius: BorderRadius.circular(KSpacing.radiusRound),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: KColors.divider,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _progressColor(status, progress),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Timestamps
          if (createdAt != null) ...[
            KSpacing.vGapSm,
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 12, color: KColors.textHint),
                const SizedBox(width: 4),
                Text(
                  'Created ${_formatDateTime(createdAt)}',
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textHint, fontSize: 11),
                ),
                if (startedAt != null) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.play_circle_outline,
                      size: 12, color: KColors.textHint),
                  const SizedBox(width: 4),
                  Text(
                    'Started ${_formatDateTime(startedAt)}',
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.textHint, fontSize: 11),
                  ),
                ],
                if (completedAt != null) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.check_circle_outline,
                      size: 12, color: KColors.textHint),
                  const SizedBox(width: 4),
                  Text(
                    'Done ${_formatDateTime(completedAt)}',
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.textHint, fontSize: 11),
                  ),
                ],
              ],
            ),
          ],

          // Expanded detail section
          if (isExpanded) ...[
            KSpacing.vGapMd,
            const Divider(height: 1),
            KSpacing.vGapMd,

            // Notes
            if (notes != null && notes.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_outlined,
                      size: 14, color: KColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      notes,
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary),
                    ),
                  ),
                ],
              ),
              KSpacing.vGapSm,
            ],

            // Lines detail
            if (lines != null && lines.isNotEmpty) ...[
              Text('Pick Lines', style: KTypography.h4),
              KSpacing.vGapSm,
              ...lines.cast<Map<String, dynamic>>().map(
                    (line) => _PicklineRow(line: line),
                  ),
            ],

            if (lines == null || lines.isEmpty)
              _PicklistDetailLoader(
                picklistId: picklist['id']?.toString() ?? '',
              ),

            // Action buttons
            KSpacing.vGapMd,
            _PicklistActions(
              status: status,
              actionInProgress: actionInProgress,
              onStart: onStart,
              onComplete: onComplete,
              onCancel: onCancel,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Pickline Row ───────────────────────────────────────────────────────

class _PicklineRow extends StatelessWidget {
  final Map<String, dynamic> line;

  const _PicklineRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final itemName = line['itemName']?.toString() ?? 'Unknown';
    final sku = line['sku']?.toString() ?? '';
    final required = (line['requiredQuantity'] as num?)?.toDouble() ?? 0;
    final picked = (line['pickedQuantity'] as num?)?.toDouble() ?? 0;
    final batchNumber = line['batchNumber']?.toString();
    final rackCode = line['rackLocationCode']?.toString();
    final lineNotes = line['notes']?.toString();
    final isComplete = picked >= required;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isComplete
            ? KColors.successLight.withValues(alpha: 0.5)
            : KColors.draftBg,
        borderRadius: KSpacing.borderRadiusSm,
        border: Border.all(
          color: isComplete
              ? KColors.success.withValues(alpha: 0.3)
              : KColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isComplete ? Icons.check_circle : Icons.circle_outlined,
                size: 16,
                color: isComplete ? KColors.success : KColors.textHint,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  itemName,
                  style: KTypography.labelMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${_fmtQty(picked)} / ${_fmtQty(required)}',
                style: KTypography.labelSmall.copyWith(
                  color: isComplete ? KColors.success : KColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          KSpacing.vGapXs,
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (sku.isNotEmpty)
                _InfoChip(icon: Icons.qr_code_2, label: sku),
              if (batchNumber != null && batchNumber.isNotEmpty)
                _InfoChip(
                    icon: Icons.inventory_2_outlined,
                    label: 'Batch $batchNumber'),
              if (rackCode != null && rackCode.isNotEmpty)
                _InfoChip(icon: Icons.shelves, label: rackCode),
              if (lineNotes != null && lineNotes.isNotEmpty)
                _InfoChip(icon: Icons.notes_outlined, label: lineNotes),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Info Chip (tiny label inside pick line) ────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: KColors.textHint),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            style: KTypography.bodySmall.copyWith(
              color: KColors.textSecondary,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Detail Loader (fetches lines when expanded and lines not in list) ─

class _PicklistDetailLoader extends ConsumerWidget {
  final String picklistId;

  const _PicklistDetailLoader({required this.picklistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (picklistId.isEmpty) {
      return const SizedBox.shrink();
    }

    final detailAsync = ref.watch(_picklistDetailProvider(picklistId));

    return detailAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Could not load pick lines',
          style: KTypography.bodySmall.copyWith(color: KColors.error),
        ),
      ),
      data: (raw) {
        final data = raw['data'] ?? raw;
        final lines = (data is Map ? (data['lines'] as List?) : null) ?? [];
        if (lines.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No pick lines',
              style:
                  KTypography.bodySmall.copyWith(color: KColors.textSecondary),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pick Lines', style: KTypography.h4),
            KSpacing.vGapSm,
            ...lines.cast<Map<String, dynamic>>().map(
                  (line) => _PicklineRow(line: line),
                ),
          ],
        );
      },
    );
  }
}

final _picklistDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get(ApiConfig.picklistById(id));
  return response.data is Map<String, dynamic>
      ? response.data as Map<String, dynamic>
      : <String, dynamic>{};
});

// ── Action Buttons ─────────────────────────────────────────────────────

class _PicklistActions extends StatelessWidget {
  final String status;
  final bool actionInProgress;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  const _PicklistActions({
    required this.status,
    required this.actionInProgress,
    required this.onStart,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];

    if (status == 'PENDING') {
      actions.add(
        FilledButton.icon(
          onPressed: actionInProgress ? null : onStart,
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: const Text('Start Picking'),
        ),
      );
      actions.add(const SizedBox(width: 8));
      actions.add(
        OutlinedButton.icon(
          onPressed: actionInProgress ? null : onCancel,
          icon: const Icon(Icons.cancel_outlined, size: 18),
          label: const Text('Cancel'),
          style: OutlinedButton.styleFrom(foregroundColor: KColors.error),
        ),
      );
    } else if (status == 'IN_PROGRESS') {
      actions.add(
        FilledButton.icon(
          onPressed: actionInProgress ? null : onComplete,
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Complete'),
          style: FilledButton.styleFrom(backgroundColor: KColors.success),
        ),
      );
      actions.add(const SizedBox(width: 8));
      actions.add(
        OutlinedButton.icon(
          onPressed: actionInProgress ? null : onCancel,
          icon: const Icon(Icons.cancel_outlined, size: 18),
          label: const Text('Cancel'),
          style: OutlinedButton.styleFrom(foregroundColor: KColors.error),
        ),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions,
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────

String _statusLabel(String status) => switch (status) {
      'PENDING' => 'Pending',
      'IN_PROGRESS' => 'In Progress',
      'COMPLETED' => 'Completed',
      'CANCELLED' => 'Cancelled',
      _ => status,
    };

/// Map picklist status to a status string that KStatusChip / KColors.statusColor
/// recognizes, giving us the desired color semantics.
String _mapStatusToChipStatus(String status) => switch (status) {
      'PENDING' => 'CONFIRMED',
      'IN_PROGRESS' => 'PARTIALLY_PAID',
      'COMPLETED' => 'PAID',
      'CANCELLED' => 'CANCELLED',
      _ => 'DRAFT',
    };

Color _statusIconColor(String status) => switch (status) {
      'PENDING' => KColors.info,
      'IN_PROGRESS' => KColors.warning,
      'COMPLETED' => KColors.success,
      'CANCELLED' => KColors.cancelled,
      _ => KColors.textSecondary,
    };

Color _statusIconBg(String status) => switch (status) {
      'PENDING' => KColors.infoLight,
      'IN_PROGRESS' => KColors.warningLight,
      'COMPLETED' => KColors.successLight,
      'CANCELLED' => KColors.cancelledBg,
      _ => KColors.draftBg,
    };

IconData _statusIcon(String status) => switch (status) {
      'PENDING' => Icons.pending_outlined,
      'IN_PROGRESS' => Icons.inventory_outlined,
      'COMPLETED' => Icons.check_circle_outline,
      'CANCELLED' => Icons.cancel_outlined,
      _ => Icons.checklist_outlined,
    };

Color _progressColor(String status, double progress) {
  if (status == 'CANCELLED') return KColors.cancelled;
  if (status == 'COMPLETED') return KColors.success;
  if (progress >= 1.0) return KColors.success;
  if (progress >= 0.5) return KColors.warning;
  return KColors.info;
}

String _fmtQty(double q) =>
    q == q.truncateToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(1);

String _formatDateTime(String iso) {
  try {
    final dt = DateTime.parse(iso);
    return DateFormat('dd MMM, HH:mm').format(dt);
  } catch (_) {
    return iso;
  }
}

String _extractError(DioException e, String fallback) {
  final body = e.response?.data;
  if (body is Map) {
    return body['message'] as String? ?? fallback;
  }
  return fallback;
}
