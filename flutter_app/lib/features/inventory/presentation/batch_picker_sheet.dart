import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/batch_repository.dart';

/// Modal batch picker for invoice / credit-note line editors on items
/// where `trackBatches = true`. Loads the FEFO-ordered list of batches
/// that currently have stock (uses the org's default warehouse — the
/// backend resolves it) and returns the selected batch as a map with
/// keys: `id`, `batchNumber`, `expiryDate`, `quantityAvailable`,
/// `unitCost`. Returns `null` if the user cancels.
///
/// The sheet short-circuits to an empty state if the item has no
/// batch stock — there is no fallback "generic deduction" because the
/// backend gate (INV_BATCH_REQUIRED) would reject the post anyway.
Future<Map<String, dynamic>?> showBatchPicker(
  BuildContext context, {
  required String itemId,
  required String itemName,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => _BatchPickerSheet(
        itemId: itemId,
        itemName: itemName,
        scrollController: scrollController,
      ),
    ),
  );
}

class _BatchPickerSheet extends ConsumerStatefulWidget {
  final String itemId;
  final String itemName;
  final ScrollController scrollController;

  const _BatchPickerSheet({
    required this.itemId,
    required this.itemName,
    required this.scrollController,
  });

  @override
  ConsumerState<_BatchPickerSheet> createState() => _BatchPickerSheetState();
}

class _BatchPickerSheetState extends ConsumerState<_BatchPickerSheet> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    return ref
        .read(batchRepositoryProvider)
        .availableForItem(widget.itemId);
  }

  void _retry() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                KSpacing.md, KSpacing.md, KSpacing.md, KSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 20, color: KColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Pick Batch', style: KTypography.h3),
                    ),
                  ],
                ),
                KSpacing.vGapXs,
                Text(widget.itemName,
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.textSecondary)),
                KSpacing.vGapXs,
                Text(
                  'Ordered by earliest expiry — FEFO',
                  style: KTypography.labelSmall
                      .copyWith(color: KColors.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const KShimmerList();
                }
                if (snap.hasError) {
                  debugPrint('[BatchPicker] ERROR: ${snap.error}');
                  return KErrorView(
                    message: 'Failed to load batches',
                    onRetry: _retry,
                  );
                }
                final batches = snap.data ?? const [];
                if (batches.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(KSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inbox_outlined,
                            size: 48, color: KColors.textSecondary),
                        KSpacing.vGapMd,
                        Text('No batch stock available',
                            style: KTypography.labelLarge),
                        KSpacing.vGapXs,
                        Text(
                          'This item is batch-tracked but has no on-hand '
                          'stock. Receive a batch via Stock Receipt first.',
                          textAlign: TextAlign.center,
                          style: KTypography.bodySmall
                              .copyWith(color: KColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  controller: widget.scrollController,
                  padding: KSpacing.pagePadding,
                  itemCount: batches.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final batch = batches[i];
                    return _BatchTile(
                      batch: batch,
                      isEarliest: i == 0,
                      onTap: () => Navigator.pop(context, batch),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BatchTile extends StatelessWidget {
  final Map<String, dynamic> batch;
  final bool isEarliest;
  final VoidCallback onTap;

  const _BatchTile({
    required this.batch,
    required this.isEarliest,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final expiry = batch['expiryDate']?.toString();
    final available = (batch['quantityAvailable'] as num?)?.toDouble() ?? 0;
    final unitCost = (batch['unitCost'] as num?)?.toDouble() ?? 0;
    final expiryStatus = _expiryStatus(expiry);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      onTap: onTap,
      title: Row(
        children: [
          Expanded(
            child: Text(
              batch['batchNumber']?.toString() ?? '(no batch number)',
              style: KTypography.labelLarge,
            ),
          ),
          if (isEarliest)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: KColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'FEFO',
                style: KTypography.labelSmall.copyWith(
                  color: KColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 12, color: KColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              expiry != null ? 'Expires $expiry' : 'No expiry',
              style: KTypography.bodySmall.copyWith(
                color: expiryStatus.color,
                fontWeight: expiryStatus.isUrgent
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.currency_rupee,
                size: 12, color: KColors.textSecondary),
            Text(
              unitCost.toStringAsFixed(2),
              style: KTypography.bodySmall
                  .copyWith(color: KColors.textSecondary),
            ),
          ],
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            available.toStringAsFixed(available == available.roundToDouble() ? 0 : 2),
            style: KTypography.amountSmall,
          ),
          Text('available',
              style: KTypography.labelSmall
                  .copyWith(color: KColors.textSecondary)),
        ],
      ),
    );
  }

  _ExpiryStatus _expiryStatus(String? expiry) {
    if (expiry == null) {
      return const _ExpiryStatus(KColors.textSecondary, false);
    }
    final parsed = DateTime.tryParse(expiry);
    if (parsed == null) {
      return const _ExpiryStatus(KColors.textSecondary, false);
    }
    final days = parsed.difference(DateTime.now()).inDays;
    if (days < 0) return const _ExpiryStatus(KColors.error, true);
    if (days <= 30) return const _ExpiryStatus(KColors.warning, true);
    return const _ExpiryStatus(KColors.textSecondary, false);
  }
}

class _ExpiryStatus {
  final Color color;
  final bool isUrgent;
  const _ExpiryStatus(this.color, this.isUrgent);
}
