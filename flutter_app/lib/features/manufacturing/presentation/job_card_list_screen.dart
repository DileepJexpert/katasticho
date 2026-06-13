import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/k_keyboard_list_wrapper.dart';
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
          loading: () => const Center(child: CircularProgressIndicator()),
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
            // Sort by sequence number
            final sorted = [...cards]
              ..sort((a, b) =>
                  ((a['sequenceNumber'] as num?)?.compareTo(
                          (b['sequenceNumber'] as num?) ?? 0) ??
                      0));
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(jobCardsProvider(widget.workOrderId)),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtl,
              decoration: const InputDecoration(labelText: 'Quantity *'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
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
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
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
    final theme = Theme.of(context);
    final seq = card['sequenceNumber']?.toString() ?? '-';
    final opId = card['operationId']?.toString() ?? '';
    final truncOpId =
        opId.length > 16 ? '${opId.substring(0, 8)}…' : opId;
    final status = card['status']?.toString() ?? 'PENDING';
    final plannedQty = card['plannedQty']?.toString() ?? '0';
    final completedQty = card['completedQty']?.toString() ?? '0';
    final timeLogged = card['timeLoggedMinutes']?.toString() ?? '0';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Sequence badge
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  seq,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        KStatusChip(status: status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 16,
                      children: [
                        Text('Planned: $plannedQty',
                            style: theme.textTheme.bodySmall),
                        Text('Done: $completedQty',
                            style: theme.textTheme.bodySmall),
                        Text('Time: ${timeLogged}m',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) => switch (status) {
        'PENDING' => Colors.grey,
        'IN_PROGRESS' => Colors.blue,
        'COMPLETED' => Colors.green,
        _ => Colors.grey,
      };
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
    final theme = Theme.of(context);
    final status = card['status']?.toString() ?? 'PENDING';
    final id = card['id']?.toString() ?? '';
    final seq = card['sequenceNumber']?.toString() ?? '-';
    final opId = card['operationId']?.toString() ?? '';
    final wsId = card['workstationId']?.toString() ?? '';
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
          // Header
          Row(
            children: [
              Text('Step $seq',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              KStatusChip(status: status),
            ],
          ),
          const SizedBox(height: 12),

          // Details grid
          KCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
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
          const SizedBox(height: 16),

          // Actions
          if (status == 'PENDING')
            FilledButton.icon(
              onPressed: () => _startCard(context, ref, id),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Job Card'),
            ),
          if (status == 'IN_PROGRESS')
            FilledButton.icon(
              onPressed: () => _showCompleteDialog(context, ref, id),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Complete Job Card'),
            ),
          if (status == 'COMPLETED')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Text('This job card is completed.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.green.shade800)),
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
              content: Text('Job card started'), backgroundColor: Colors.blue),
        );
      }
      onAction();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
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
              const SizedBox(height: 12),
              TextField(
                controller: scrapQtyCtl,
                decoration:
                    const InputDecoration(labelText: 'Scrap Qty'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeCtl,
                decoration: const InputDecoration(
                    labelText: 'Time Logged (minutes)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtl,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete'),
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
              backgroundColor: Colors.green),
        );
      }
      onAction();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey)),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
