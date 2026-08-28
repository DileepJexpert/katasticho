import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/routing_repository.dart';

class JobCardListScreen extends ConsumerStatefulWidget {
  const JobCardListScreen({
    super.key,
    required this.workOrderId,
    required this.workOrderNumber,
  });

  final String workOrderId;
  final String workOrderNumber;

  @override
  ConsumerState<JobCardListScreen> createState() => _JobCardListScreenState();
}

class _JobCardListScreenState extends ConsumerState<JobCardListScreen> {
  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(jobCardsProvider(widget.workOrderId));

    return KKeyboardListWrapper(
      itemCount: () => cardsAsync.valueOrNull?.length ?? 0,
      onNew: _showCreateJobCardsDialog,
      onRefresh: () => ref.invalidate(jobCardsProvider(widget.workOrderId)),
      onOpen: (index) {
        final cards = cardsAsync.valueOrNull;
        if (cards != null && index < cards.length) {
          final sorted = [...cards]
            ..sort((a, b) =>
                ((a['sequenceNumber'] as num?)?.compareTo(
                        (b['sequenceNumber'] as num?) ?? 0) ??
                    0));
          _showCardSheet(sorted[index]);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Job Cards — ${widget.workOrderNumber}'),
        ),
        body: cardsAsync.when(
          loading: () => const Center(child: KLoading(message: 'Loading job cards...')),
          error: (e, _) => KErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(jobCardsProvider(widget.workOrderId)),
          ),
          data: (cards) {
            if (cards.isEmpty) {
              return const KEmptyState(
                icon: Icons.assignment_outlined,
                title: 'No job cards',
                subtitle:
                    'Tap the button below to create job cards from a routing.',
              );
            }
            final sorted = [...cards]
              ..sort((a, b) =>
                  ((a['sequenceNumber'] as num?)?.compareTo(
                          (b['sequenceNumber'] as num?) ?? 0) ??
                      0));
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(jobCardsProvider(widget.workOrderId)),
              child: ListView.builder(
                padding: KSpacing.pagePadding,
                itemCount: sorted.length,
                itemBuilder: (ctx, i) => _JobCardItem(
                  card: sorted[i],
                  onTap: () => _showCardSheet(sorted[i]),
                ),
              ),
            );
          },
        ),
        floatingActionButton: cardsAsync.maybeWhen(
          data: (cards) => cards.isEmpty
              ? FloatingActionButton.extended(
                  backgroundColor: KColors.primary,
                  foregroundColor: Colors.white,
                  onPressed: _showCreateJobCardsDialog,
                  icon: const Icon(Icons.post_add),
                  label: const Text('Create Job Cards'),
                  tooltip: 'Create Job Cards (N)',
                )
              : null,
          orElse: () => null,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom sheet per card
  // ---------------------------------------------------------------------------

  void _showCardSheet(Map<String, dynamic> card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _JobCardSheet(
        card: card,
        onAction: () {
          Navigator.pop(ctx);
          ref.invalidate(jobCardsProvider(widget.workOrderId));
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Create Job Cards dialog (when list is empty)
  // ---------------------------------------------------------------------------

  Future<void> _showCreateJobCardsDialog() async {
    final routingIdCtl = TextEditingController();
    final qtyCtl = TextEditingController(text: '1');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Job Cards'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: routingIdCtl,
              decoration: const InputDecoration(
                labelText: 'Routing ID (UUID) *',
                hintText: 'e.g. 550e8400-e29b-41d4-a716-446655440000',
              ),
              autofocus: true,
            ),
            KSpacing.vGapSm,
            TextField(
              controller: qtyCtl,
              decoration: const InputDecoration(labelText: 'Quantity *'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          KButton.outlined(
            label: 'Cancel',
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          KSpacing.hGapSm,
          KButton.primary(
            label: 'Create',
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final routingId = routingIdCtl.text.trim();
    final qty = double.tryParse(qtyCtl.text.trim());

    if (routingId.isEmpty || qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid routing ID and quantity')),
      );
      return;
    }

    try {
      await ref.read(routingRepositoryProvider).createJobCards(
            workOrderId: widget.workOrderId,
            routingId: routingId,
            qty: qty,
          );
      ref.invalidate(jobCardsProvider(widget.workOrderId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job cards created successfully'),
            backgroundColor: KColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error));
      }
    }
  }
}
// ---------------------------------------------------------------------------
// Job card list item
// ---------------------------------------------------------------------------

class _JobCardItem extends StatelessWidget {
  const _JobCardItem({required this.card, required this.onTap});
  final Map<String, dynamic> card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final seq = card['sequenceNumber']?.toString() ?? '-';
    final opId = card['operationId']?.toString() ?? '';
    final opName = card['operationName']?.toString();
    final truncOpId = (opName != null && opName.isNotEmpty)
        ? opName
        : (opId.length > 16 ? '${opId.substring(0, 8)}…' : opId);
    final status = card['status']?.toString() ?? 'PENDING';
    final plannedQty = card['plannedQty']?.toString() ?? '0';
    final completedQty = card['completedQty']?.toString() ?? '0';
    final timeLogged = card['timeLoggedMinutes']?.toString() ?? '0';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: KColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  seq,
                  style: KTypography.labelMedium.copyWith(
                    color: KColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (truncOpId.isNotEmpty)
                          Expanded(
                            child: Text(
                              truncOpId,
                              style: KTypography.labelLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        KStatusChip(status: status),
                      ],
                    ),
                    KSpacing.vGapXs,
                    Wrap(
                      spacing: 16,
                      children: [
                        Text('Planned: $plannedQty', style: KTypography.bodySmall),
                        Text('Done: $completedQty', style: KTypography.bodySmall),
                        Text('Time: ${timeLogged}m', style: KTypography.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: KColors.textHint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Job card action bottom sheet
// ---------------------------------------------------------------------------

class _JobCardSheet extends ConsumerWidget {
  const _JobCardSheet({required this.card, required this.onAction});
  final Map<String, dynamic> card;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = card['status']?.toString() ?? 'PENDING';
    final id = card['id']?.toString() ?? '';
    final seq = card['sequenceNumber']?.toString() ?? '-';
    final opId = card['operationName']?.toString() ??
        card['operationId']?.toString() ??
        '';
    final wsId = card['workstationName']?.toString() ??
        card['workstationId']?.toString() ??
        '';
    final plannedQty = card['plannedQty']?.toString() ?? '0';
    final completedQty = card['completedQty']?.toString() ?? '0';
    final scrapQty = card['scrapQty']?.toString() ?? '0';
    final timeLogged = card['timeLoggedMinutes']?.toString() ?? '0';
    final actualStart = card['actualStart']?.toString();
    final actualEnd = card['actualEnd']?.toString();
    final notes = card['notes']?.toString() ?? '';

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Step $seq', style: KTypography.h3),
              KSpacing.hGapMd,
              KStatusChip(status: status),
            ],
          ),
          KSpacing.vGapMd,

          KCard(
            child: Padding(
              padding: const EdgeInsets.all(KSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (opId.isNotEmpty) _InfoRow('Operation', opId),
                  if (wsId.isNotEmpty) _InfoRow('Workstation', wsId),
                  _InfoRow('Planned Qty', plannedQty),
                  _InfoRow('Completed Qty', completedQty),
                  _InfoRow('Scrap Qty', scrapQty),
                  _InfoRow('Time Logged', '${timeLogged}m'),
                  if (actualStart != null) _InfoRow('Started', actualStart),
                  if (actualEnd != null) _InfoRow('Ended', actualEnd),
                  if (notes.isNotEmpty) _InfoRow('Notes', notes),
                ],
              ),
            ),
          ),
          KSpacing.vGapLg,

          if (status == 'PENDING')
            KButton.primary(
              onPressed: () => _startCard(context, ref, id),
              icon: Icons.play_arrow,
              label: 'Start Job Card',
            ),
          if (status == 'IN_PROGRESS')
            KButton.primary(
              onPressed: () => _showCompleteDialog(context, ref, id),
              icon: Icons.check_circle_outline,
              label: 'Complete Job Card',
            ),
          if (status == 'COMPLETED')
            Container(
              padding: const EdgeInsets.all(KSpacing.md),
              decoration: BoxDecoration(
                color: KColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: KColors.success.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: KColors.success),
                  KSpacing.hGapSm,
                  Text(
                    'This job card is completed.',
                    style: KTypography.bodyMedium.copyWith(color: KColors.success),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _startCard(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(routingRepositoryProvider).startJobCard(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Job card started'), backgroundColor: KColors.info),
        );
      }
      onAction();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error));
      }
    }
  }

  Future<void> _showCompleteDialog(
      BuildContext context, WidgetRef ref, String id) async {
    final completedQtyCtl =
        TextEditingController(text: card['plannedQty']?.toString() ?? '');
    final scrapQtyCtl = TextEditingController(text: '0');
    final timeCtl = TextEditingController();
    final notesCtl = TextEditingController(text: card['notes']?.toString() ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Job Card'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: completedQtyCtl,
                decoration:
                    const InputDecoration(labelText: 'Completed Qty *'),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              KSpacing.vGapSm,
              TextField(
                controller: scrapQtyCtl,
                decoration:
                    const InputDecoration(labelText: 'Scrap Qty'),
                keyboardType: TextInputType.number,
              ),
              KSpacing.vGapSm,
              TextField(
                controller: timeCtl,
                decoration: const InputDecoration(
                    labelText: 'Time Logged (minutes)'),
                keyboardType: TextInputType.number,
              ),
              KSpacing.vGapSm,
              TextField(
                controller: notesCtl,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          KButton.outlined(
            label: 'Cancel',
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          KSpacing.hGapSm,
          KButton.primary(
            label: 'Complete',
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (result != true || !context.mounted) return;

    final completedQty = double.tryParse(completedQtyCtl.text.trim());
    if (completedQty == null || completedQty < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid completed quantity')),
      );
      return;
    }

    try {
      await ref.read(routingRepositoryProvider).completeJobCard(
            id,
            completedQty: completedQty,
            scrapQty: double.tryParse(scrapQtyCtl.text.trim()),
            timeLoggedMinutes: int.tryParse(timeCtl.text.trim()),
            notes: notesCtl.text.trim().isEmpty ? null : notesCtl.text.trim(),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Job card completed'),
              backgroundColor: KColors.success),
        );
      }
      onAction();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error));
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: KTypography.bodyMedium, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
