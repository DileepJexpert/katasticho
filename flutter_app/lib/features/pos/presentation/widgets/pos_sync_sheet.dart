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
import '../../data/offline_pos_service.dart';
import '../../data/pos_catalog_sync_service.dart';

/// Modal bottom sheet displaying local POS offline sync queue status,
/// connection state, and catalog cache diagnostics.
void showPosSyncSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const PosSyncSheet(),
  );
}

class PosSyncSheet extends ConsumerStatefulWidget {
  const PosSyncSheet({super.key});

  @override
  ConsumerState<PosSyncSheet> createState() => _PosSyncSheetState();
}

class _PosSyncSheetState extends ConsumerState<PosSyncSheet> {
  int _itemCount = 0;
  int _customerCount = 0;
  List<PendingReceipt> _pendingReceipts = [];
  bool _isLoading = true;
  bool _isCatalogSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final items = await OfflinePosService.instance.cachedItemCount();
    final customers = await OfflinePosService.instance.cachedCustomerCount();
    final pending = await OfflinePosService.instance.getPendingReceipts();
    if (mounted) {
      setState(() {
        _itemCount = items;
        _customerCount = customers;
        _pendingReceipts = pending;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(posOnlineProvider).valueOrNull ?? true;
    final syncStatus = ref.watch(offlineSyncStatusProvider).valueOrNull ?? SyncStatus.idle;
    final isSyncing = syncStatus == SyncStatus.syncing;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(KSpacing.lg, KSpacing.md, KSpacing.sm, KSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Offline Sync & Local Cache', style: KTypography.h3),
                        KSpacing.vGapXs,
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isOnline ? KColors.success : KColors.error,
                              ),
                            ),
                            KSpacing.hGapXs,
                            Text(
                              isOnline ? 'Online · Live Sync Active' : 'Offline · Storing Locally',
                              style: KTypography.caption.copyWith(
                                color: isOnline ? KColors.success : KColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(KSpacing.md),
                children: [
                  // Diagnostics stats
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Pending Sync',
                          value: '${_pendingReceipts.length}',
                          icon: Icons.sync,
                          color: _pendingReceipts.isEmpty ? KColors.textSecondary : KColors.primary,
                        ),
                      ),
                      KSpacing.hGapSm,
                      Expanded(
                        child: _StatCard(
                          title: 'Items Cached',
                          value: '$_itemCount',
                          icon: Icons.inventory_2_outlined,
                          color: KColors.textPrimary,
                        ),
                      ),
                      KSpacing.hGapSm,
                      Expanded(
                        child: _StatCard(
                          title: 'Customers',
                          value: '$_customerCount',
                          icon: Icons.people_outline,
                          color: KColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  KSpacing.vGapMd,

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: KButton(
                          label: isSyncing ? 'Syncing...' : 'Sync Pending Queue',
                          icon: Icons.cloud_upload_outlined,
                          isLoading: isSyncing,
                          onPressed: _pendingReceipts.isEmpty || isSyncing
                              ? null
                              : () async {
                                  await OfflinePosService.instance.syncPendingReceipts();
                                  await _loadStats();
                                },
                        ),
                      ),
                      KSpacing.hGapSm,
                      Expanded(
                        child: KButton(
                          label: _isCatalogSyncing ? 'Downloading...' : 'Pre-cache Catalog',
                          icon: Icons.cloud_download_outlined,
                          variant: KButtonVariant.outlined,
                          isLoading: _isCatalogSyncing,
                          onPressed: _isCatalogSyncing
                              ? null
                              : () async {
                                  setState(() => _isCatalogSyncing = true);
                                  try {
                                    await PosCatalogSyncService.instance.fullPreSync();
                                    await _loadStats();
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isCatalogSyncing = false);
                                    }
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                  KSpacing.vGapLg,

                  // Pending queue list header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pending Receipts (${_pendingReceipts.length})',
                        style: KTypography.h4,
                      ),
                      if (_pendingReceipts.isNotEmpty)
                        TextButton(
                          onPressed: () async {
                            await OfflinePosService.instance.clearAll();
                            await _loadStats();
                          },
                          child: Text(
                            'Clear Queue',
                            style: KTypography.labelSmall.copyWith(color: KColors.error),
                          ),
                        ),
                    ],
                  ),
                  KSpacing.vGapSm,

                  if (_isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(KSpacing.xl), child: CircularProgressIndicator()))
                  else if (_pendingReceipts.isEmpty)
                    const KEmptyState(
                      icon: Icons.check_circle_outline,
                      title: 'All Receipts Synced',
                      subtitle: 'No offline receipts are waiting to sync with the server.',
                    )
                  else
                    ..._pendingReceipts.map((receipt) => _ReceiptQueueCard(
                          receipt: receipt,
                          onDeleted: () async {
                            if (receipt.id != null) {
                              await OfflinePosService.instance.deleteReceipt(receipt.id!);
                              await _loadStats();
                            }
                          },
                        )),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      padding: const EdgeInsets.all(KSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: KColors.textSecondary),
              KSpacing.hGapXs,
              Expanded(
                child: Text(
                  title,
                  style: KTypography.caption.copyWith(color: KColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          KSpacing.vGapXs,
          Text(
            value,
            style: KTypography.h3.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _ReceiptQueueCard extends StatelessWidget {
  final PendingReceipt receipt;
  final VoidCallback onDeleted;

  const _ReceiptQueueCard({
    required this.receipt,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final body = receipt.requestBody;
    final offlineNo = body['offlineReceiptNumber']?.toString() ?? 'ID #${receipt.id}';
    final total = (body['netPayable'] ?? body['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final lines = (body['lines'] as List?)?.length ?? 0;
    final customer = body['contactName']?.toString() ?? 'Walk-in';
    final mode = body['paymentMode']?.toString() ?? 'CASH';

    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: KCard(
        padding: const EdgeInsets.all(KSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(offlineNo, style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w600)),
                      KSpacing.hGapSm,
                      KStatusChip(status: mode),
                      if (receipt.retryCount > 0) ...[
                        KSpacing.hGapXs,
                        KStatusChip(status: 'RETRY: ${receipt.retryCount}'),
                      ],
                    ],
                  ),
                  KSpacing.vGapXs,
                  Text(
                    '$customer · $lines items · ${receipt.createdAt.substring(0, 16).replaceFirst('T', ' ')}',
                    style: KTypography.caption.copyWith(color: KColors.textSecondary),
                  ),
                  if (receipt.lastError != null) ...[
                    KSpacing.vGapXs,
                    Text(
                      receipt.lastError!,
                      style: KTypography.caption.copyWith(color: KColors.error),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            KMoney(total, style: KTypography.amountMedium),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: KColors.textSecondary),
              tooltip: 'Discard',
              onPressed: onDeleted,
            ),
          ],
        ),
      ),
    );
  }
}
