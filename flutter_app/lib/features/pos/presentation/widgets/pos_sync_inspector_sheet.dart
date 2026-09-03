import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/widgets/k_button.dart';
import '../../../../core/widgets/k_card.dart';
import '../../../../core/widgets/k_empty_state.dart';
import '../../../../core/widgets/k_money.dart';
import '../../../../core/widgets/k_status_chip.dart';
import '../../data/network_health_service.dart';
import '../../data/offline_pos_service.dart';
import '../../data/pos_catalog_sync_service.dart';

/// Modal / Slide-out inspector console for POS counter network health,
/// SQLite database diagnostics, and pending receipt queue.
void showPosSyncInspectorSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(KSpacing.radiusMd)),
    ),
    builder: (_) => const PosSyncInspectorSheet(),
  );
}

class PosSyncInspectorSheet extends ConsumerStatefulWidget {
  const PosSyncInspectorSheet({super.key});

  @override
  ConsumerState<PosSyncInspectorSheet> createState() => _PosSyncInspectorSheetState();
}

class _PosSyncInspectorSheetState extends ConsumerState<PosSyncInspectorSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DatabaseStats? _dbStats;
  List<PendingReceipt> _pendingReceipts = [];
  bool _isLoading = true;
  bool _isCatalogSyncing = false;
  bool _isOptimizingDb = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDiagnostics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDiagnostics() async {
    final stats = await OfflinePosService.instance.getDatabaseStats();
    final pending = await OfflinePosService.instance.getPendingReceipts();
    if (mounted) {
      setState(() {
        _dbStats = stats;
        _pendingReceipts = pending;
        _isLoading = false;
      });
    }
  }

  Future<void> _optimizeDatabase() async {
    setState(() => _isOptimizingDb = true);
    try {
      await OfflinePosService.instance.vacuumAndOptimize();
      await _loadDiagnostics();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SQLite database vacuumed and reindexed successfully!'),
            backgroundColor: KColors.success,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isOptimizingDb = false);
    }
  }

  Future<void> _retrySingle(int id) async {
    final success = await OfflinePosService.instance.retrySingleReceipt(id, ref: ref);
    await _loadDiagnostics();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Receipt synced successfully!' : 'Receipt sync failed. Kept in queue.'),
          backgroundColor: success ? KColors.success : KColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final network = ref.watch(networkHealthProvider);
    final syncStatus = ref.watch(offlineSyncStatusProvider).valueOrNull ?? SyncStatus.idle;
    final isSyncing = syncStatus == SyncStatus.syncing;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            // Inspector Header
            Padding(
              padding: const EdgeInsets.fromLTRB(KSpacing.lg, KSpacing.md, KSpacing.sm, KSpacing.xs),
              child: Row(
                children: [
                  const Icon(Icons.hub_outlined, color: KColors.primary, size: 24),
                  KSpacing.hGapSm,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sync Inspector & Network Health', style: KTypography.h3),
                        KSpacing.vGapXxs,
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: network.isOnline ? KColors.success : KColors.error,
                              ),
                            ),
                            KSpacing.hGapXs,
                            Text(
                              '${network.qualityLabel} · ${network.connectionType}',
                              style: KTypography.caption.copyWith(
                                color: network.isOnline ? KColors.success : KColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            KSpacing.hGapSm,
                            Text(
                              'Reliability: ${(network.packetSuccessRate * 100).toInt()}%',
                              style: KTypography.caption.copyWith(color: KColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh Diagnostics',
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () {
                      ref.read(networkHealthProvider.notifier).probeHealth();
                      _loadDiagnostics();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 16),
                      KSpacing.hGapXs,
                      Text('Offline Queue (${_pendingReceipts.length})'),
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.storage_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('SQLite & Cache Health'),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 1),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Queue Inspector
                  _buildQueueTab(scrollController, isSyncing),

                  // Tab 2: SQLite Diagnostics
                  _buildDiagnosticsTab(scrollController, network),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQueueTab(ScrollController scrollController, bool isSyncing) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalQueuedAmount = _pendingReceipts.fold<double>(
      0.0,
      (sum, r) => sum + ((r.requestBody['netPayable'] ?? r.requestBody['totalAmount'] as num?)?.toDouble() ?? 0.0),
    );

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(KSpacing.md),
      children: [
        // Action & Summary Bar
        KCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pending Receipts Value', style: KTypography.caption),
                    KSpacing.vGapXs,
                    KMoney(totalQueuedAmount, style: KTypography.h2),
                    KSpacing.vGapXxs,
                    Text(
                      '${_pendingReceipts.length} transactions waiting to post to server',
                      style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                    ),
                  ],
                ),
              ),
              KButton.primary(
                label: isSyncing ? 'Syncing...' : 'Sync Queue Now',
                icon: Icons.cloud_upload_outlined,
                isLoading: isSyncing,
                onPressed: _pendingReceipts.isEmpty || isSyncing
                    ? null
                    : () async {
                        await OfflinePosService.instance.syncPendingReceipts(ref: ref);
                        await _loadDiagnostics();
                      },
              ),
            ],
          ),
        ),
        KSpacing.vGapMd,

        // Receipts List Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Queued Offline Sales', style: KTypography.h4),
            if (_pendingReceipts.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: KColors.error),
                label: Text('Clear All', style: TextStyle(color: KColors.error, fontSize: 12)),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Discard all pending receipts?'),
                      content: const Text('This will delete all offline sales that have not synced yet.'),
                      actions: [
                        KButton.secondary(label: 'Cancel', onPressed: () => Navigator.pop(c, false)),
                        KButton.primary(label: 'Discard All', onPressed: () => Navigator.pop(c, true)),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await OfflinePosService.instance.clearAll();
                    await _loadDiagnostics();
                  }
                },
              ),
          ],
        ),
        KSpacing.vGapSm,

        if (_pendingReceipts.isEmpty)
          const KCard(
            child: KEmptyState(
              icon: Icons.check_circle_outline,
              title: 'Offline Queue Clear',
              subtitle: 'All counter sales have been uploaded and posted to the ERP server.',
            ),
          )
        else
          ..._pendingReceipts.map(
            (receipt) => _InspectorReceiptCard(
              receipt: receipt,
              onRetry: receipt.id != null ? () => _retrySingle(receipt.id!) : null,
              onDeleted: () async {
                if (receipt.id != null) {
                  await OfflinePosService.instance.deleteReceipt(receipt.id!);
                  await _loadDiagnostics();
                }
              },
            ),
          ),
      ],
    );
  }

  Widget _buildDiagnosticsTab(ScrollController scrollController, NetworkHealthState network) {
    final stats = _dbStats;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(KSpacing.md),
      children: [
        // Network Quality Card
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.speed_outlined, color: KColors.primary, size: 20),
                  KSpacing.hGapSm,
                  Text('Active Telemetry & Round-Trip Ping', style: KTypography.labelLarge),
                ],
              ),
              KSpacing.vGapMd,
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ping Latency', style: KTypography.caption),
                        KSpacing.vGapXs,
                        Text('${network.latencyMs} ms', style: KTypography.h3),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Packet Health', style: KTypography.caption),
                        KSpacing.vGapXs,
                        Text('${(network.packetSuccessRate * 100).toInt()}%',
                            style: KTypography.h3.copyWith(
                                color: network.packetSuccessRate > 0.8 ? KColors.success : KColors.warning)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Connection Type', style: KTypography.caption),
                        KSpacing.vGapXs,
                        Text(network.connectionType, style: KTypography.labelLarge),
                      ],
                    ),
                  ),
                ],
              ),
              KSpacing.vGapSm,
              // Ping sparkline simulation
              Row(
                children: [
                  Text('Latency Trend (last 10): ', style: KTypography.caption),
                  KSpacing.hGapSm,
                  Expanded(
                    child: Row(
                      children: network.latencyHistory.map((p) {
                        final color = p < 80 ? KColors.success : (p < 250 ? KColors.warning : KColors.error);
                        return Container(
                          margin: const EdgeInsets.only(right: 4),
                          width: 8,
                          height: (p / 20).clamp(4, 20).toDouble(),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        KSpacing.vGapMd,

        // Local SQLite Database Card
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.dns_outlined, color: KColors.primary, size: 20),
                  KSpacing.hGapSm,
                  Text('Local SQLite Database Health', style: KTypography.labelLarge),
                  const Spacer(),
                  KStatusChip(
                    status: stats?.integrityOk == true ? 'PRAGMA: Healthy' : 'Warning',
                    dense: true,
                  ),
                ],
              ),
              KSpacing.vGapMd,
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DB File Size', style: KTypography.caption),
                        KSpacing.vGapXs,
                        Text(stats?.fileSizeFormatted ?? '0 KB', style: KTypography.h3),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Items Cached', style: KTypography.caption),
                        KSpacing.vGapXs,
                        Text('${stats?.cachedItemCount ?? 0}', style: KTypography.h3),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Customers Cached', style: KTypography.caption),
                        KSpacing.vGapXs,
                        Text('${stats?.cachedCustomerCount ?? 0}', style: KTypography.h3),
                      ],
                    ),
                  ),
                ],
              ),
              KSpacing.vGapMd,
              Row(
                children: [
                  Expanded(
                    child: KButton.secondary(
                      label: _isOptimizingDb ? 'Optimizing...' : 'Vacuum & Reindex DB',
                      icon: Icons.cleaning_services_outlined,
                      isLoading: _isOptimizingDb,
                      onPressed: _isOptimizingDb ? null : _optimizeDatabase,
                    ),
                  ),
                  KSpacing.hGapSm,
                  Expanded(
                    child: KButton(
                      label: _isCatalogSyncing ? 'Downloading...' : 'Re-sync Catalog',
                      icon: Icons.cloud_download_outlined,
                      variant: KButtonVariant.outlined,
                      isLoading: _isCatalogSyncing,
                      onPressed: _isCatalogSyncing
                          ? null
                          : () async {
                              setState(() => _isCatalogSyncing = true);
                              try {
                                await PosCatalogSyncService.instance.fullPreSync();
                                await _loadDiagnostics();
                              } finally {
                                if (mounted) setState(() => _isCatalogSyncing = false);
                              }
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InspectorReceiptCard extends StatefulWidget {
  final PendingReceipt receipt;
  final VoidCallback? onRetry;
  final VoidCallback onDeleted;

  const _InspectorReceiptCard({
    required this.receipt,
    this.onRetry,
    required this.onDeleted,
  });

  @override
  State<_InspectorReceiptCard> createState() => _InspectorReceiptCardState();
}

class _InspectorReceiptCardState extends State<_InspectorReceiptCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final body = widget.receipt.requestBody;
    final offlineNo = body['offlineReceiptNumber']?.toString() ?? 'ID #${widget.receipt.id}';
    final total = (body['netPayable'] ?? body['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final lines = (body['lines'] as List?) ?? [];
    final customer = body['contactName']?.toString() ?? 'Walk-in Customer';
    final mode = body['paymentMode']?.toString() ?? 'CASH';

    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: KCard(
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(offlineNo, style: KTypography.mono(fontSize: 14, fontWeight: FontWeight.w600)),
                            KSpacing.hGapSm,
                            KStatusChip(status: mode, dense: true),
                            if (widget.receipt.retryCount > 0) ...[
                              KSpacing.hGapXs,
                              KStatusChip(
                                status: 'Retry: ${widget.receipt.retryCount}',
                                dense: true,
                              ),
                            ],
                          ],
                        ),
                        KSpacing.vGapXs,
                        Text(
                          '$customer · ${lines.length} items · ${widget.receipt.createdAt.substring(0, 16).replaceFirst('T', ' ')}',
                          style: KTypography.caption.copyWith(color: KColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  KMoney(total, style: KTypography.amountMedium),
                  KSpacing.hGapSm,
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 20, color: KColors.textSecondary),
                ],
              ),
            ),

            if (_expanded) ...[
              const Divider(height: 16),
              // Line items breakdown
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('Line Items (${lines.length}):', style: KTypography.caption.copyWith(fontWeight: FontWeight.w600)),
              ),
              KSpacing.vGapXs,
              ...lines.map((l) {
                final lMap = l as Map<String, dynamic>;
                final itemName = lMap['itemName'] ?? lMap['name'] ?? 'Item';
                final qty = lMap['quantity'] ?? lMap['qty'] ?? 1;
                final price = (lMap['unitPrice'] ?? lMap['price'] as num?)?.toDouble() ?? 0.0;
                final lineTotal = (lMap['lineTotal'] ?? lMap['total'] as num?)?.toDouble() ?? (qty * price);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$itemName (x$qty)', style: KTypography.bodySmall),
                      KMoney(lineTotal, style: KTypography.caption),
                    ],
                  ),
                );
              }),

              if (widget.receipt.lastError != null) ...[
                KSpacing.vGapSm,
                Container(
                  padding: const EdgeInsets.all(KSpacing.xs),
                  decoration: BoxDecoration(
                    color: KColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(KSpacing.radiusMd),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: KColors.error),
                      KSpacing.hGapXs,
                      Expanded(
                        child: Text(
                          widget.receipt.lastError!,
                          style: KTypography.caption.copyWith(color: KColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              KSpacing.vGapSm,
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.onRetry != null)
                    KButton.primary(
                      label: 'Retry Push',
                      icon: Icons.sync,
                      onPressed: widget.onRetry,
                    ),
                  KSpacing.hGapSm,
                  KButton.secondary(
                    label: 'Discard',
                    icon: Icons.delete_outline,
                    onPressed: widget.onDeleted,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}