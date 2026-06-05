import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/location_service.dart';
import '../../../core/widgets/widgets.dart';
import '../data/field_sales_repository.dart';

class RouteExecutionDetailScreen extends ConsumerStatefulWidget {
  const RouteExecutionDetailScreen({super.key, required this.executionId});
  final String executionId;

  @override
  ConsumerState<RouteExecutionDetailScreen> createState() =>
      _RouteExecutionDetailScreenState();
}

class _RouteExecutionDetailScreenState
    extends ConsumerState<RouteExecutionDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _execution;
  List<Map<String, dynamic>> _visits = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(fieldSalesRepositoryProvider);
      final results = await Future.wait([
        repo.getExecution(widget.executionId),
        repo.getVisits(widget.executionId),
      ]);
      if (mounted) {
        setState(() {
          _execution = results[0] as Map<String, dynamic>;
          _visits = (results[1] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load execution: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _visitStatusColor(String status) {
    switch (status) {
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.green;
      case 'SKIPPED':
        return Colors.red;
      case 'PLANNED':
      default:
        return Colors.blue;
    }
  }

  Future<void> _checkIn(String visitId) async {
    try {
      final pos = await LocationService.getCurrentPosition();
      final lat = pos?.latitude ?? 0;
      final lng = pos?.longitude ?? 0;
      if (pos == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location unavailable — using default')),
        );
      }
      await ref
          .read(fieldSalesRepositoryProvider)
          .checkIn(visitId, lat, lng);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checked in successfully'),
            backgroundColor: KColors.success,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to check in: $e')),
        );
      }
    }
  }

  Future<void> _checkOut(String visitId) async {
    final notesCtl = TextEditingController();
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check Out'),
        content: TextField(
          controller: notesCtl,
          decoration: const InputDecoration(
            labelText: 'Notes',
            hintText: 'Any visit remarks (optional)',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Check Out'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    try {
      final pos = await LocationService.getCurrentPosition();
      final lat = pos?.latitude ?? 0;
      final lng = pos?.longitude ?? 0;
      final notes = notesCtl.text.trim();
      await ref.read(fieldSalesRepositoryProvider).checkOut(
            visitId,
            lat,
            lng,
            notes: notes.isNotEmpty ? notes : null,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checked out successfully'),
            backgroundColor: KColors.success,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to check out: $e')),
        );
      }
    }
  }

  Future<void> _showSkipDialog(String visitId) async {
    final reasonCtl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Skip Visit'),
        content: TextField(
          controller: reasonCtl,
          decoration: const InputDecoration(
            labelText: 'Reason *',
            hintText: 'e.g. Shop closed, owner unavailable',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (reasonCtl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Reason is required')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Skip'),
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    try {
      await ref
          .read(fieldSalesRepositoryProvider)
          .skipVisit(visitId, reasonCtl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visit skipped')),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to skip visit: $e')),
        );
      }
    }
  }

  Future<void> _showRecordOrderDialog(String visitId) async {
    final orderValueCtl = TextEditingController();
    final salesOrderIdCtl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: salesOrderIdCtl,
              decoration: const InputDecoration(
                labelText: 'Sales Order ID',
                hintText: 'Optional',
              ),
            ),
            KSpacing.vGapSm,
            TextField(
              controller: orderValueCtl,
              decoration: const InputDecoration(
                labelText: 'Order Value *',
                hintText: 'e.g. 5000',
              ),
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
            onPressed: () {
              if (orderValueCtl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Order value is required')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    try {
      final value = double.tryParse(orderValueCtl.text.trim()) ?? 0;
      await ref.read(fieldSalesRepositoryProvider).recordOrder(
            visitId,
            salesOrderIdCtl.text.trim(),
            value,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order recorded'),
            backgroundColor: KColors.success,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record order: $e')),
        );
      }
    }
  }

  Future<void> _showRecordCollectionDialog(String visitId) async {
    final amountCtl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Collection'),
        content: TextField(
          controller: amountCtl,
          decoration: const InputDecoration(
            labelText: 'Amount *',
            hintText: 'e.g. 2500',
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (amountCtl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Amount is required')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    try {
      final amount = double.tryParse(amountCtl.text.trim()) ?? 0;
      await ref
          .read(fieldSalesRepositoryProvider)
          .recordCollection(visitId, amount);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Collection recorded'),
            backgroundColor: KColors.success,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record collection: $e')),
        );
      }
    }
  }

  Future<void> _completeRoute() async {
    try {
      await ref
          .read(fieldSalesRepositoryProvider)
          .completeExecution(widget.executionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route completed'),
            backgroundColor: KColors.success,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete route: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Execution Detail')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_execution == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Execution Detail')),
        body: const Center(child: Text('No data found')),
      );
    }

    final exec = _execution!;
    final status = exec['status']?.toString() ?? 'PLANNED';
    final routeName = exec['routeName']?.toString() ??
        exec['routeId']?.toString() ??
        '--';
    final salesperson = exec['salespersonName']?.toString() ??
        exec['salespersonId']?.toString() ??
        '--';
    final execDate = exec['date']?.toString() ?? '--';
    final totalVisits = (exec['totalVisits'] as num?)?.toInt() ?? _visits.length;
    final completedVisits = (exec['completedVisits'] as num?)?.toInt() ??
        _visits.where((v) => v['status'] == 'COMPLETED').length;
    final skippedVisits = (exec['skippedVisits'] as num?)?.toInt() ??
        _visits.where((v) => v['status'] == 'SKIPPED').length;
    final ordersTotal =
        (exec['ordersValue'] as num?)?.toDouble() ?? 0;
    final collectionsTotal =
        (exec['collections'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Execution Detail'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: KSpacing.pagePadding,
          children: [
            // -- Header Section --
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(routeName,
                            style: KTypography.labelLarge),
                      ),
                      KStatusChip(
                        status: status,
                        label: status.replaceAll('_', ' '),
                      ),
                    ],
                  ),
                  KSpacing.vGapXs,
                  Text('Date: $execDate',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary)),
                  KSpacing.vGapXs,
                  Text('Salesperson: $salesperson',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary)),
                ],
              ),
            ),
            KSpacing.vGapMd,

            // -- Summary Cards --
            Wrap(
              spacing: KSpacing.sm,
              runSpacing: KSpacing.sm,
              children: [
                _SummaryCard(
                  label: 'Planned',
                  value: '$totalVisits',
                  color: Colors.blue,
                ),
                _SummaryCard(
                  label: 'Completed',
                  value: '$completedVisits',
                  color: Colors.green,
                ),
                _SummaryCard(
                  label: 'Skipped',
                  value: '$skippedVisits',
                  color: Colors.red,
                ),
                _SummaryCard(
                  label: 'Orders',
                  value: CurrencyFormatter.formatIndian(ordersTotal),
                  color: KColors.primary,
                ),
                _SummaryCard(
                  label: 'Collections',
                  value: CurrencyFormatter.formatIndian(collectionsTotal),
                  color: KColors.success,
                ),
              ],
            ),
            KSpacing.vGapMd,

            // -- Visits Section --
            Text('Visits', style: KTypography.labelLarge),
            KSpacing.vGapSm,
            if (_visits.isEmpty)
              const Center(child: Text('No visits found'))
            else
              ..._visits.map((visit) {
                final visitId = visit['id']?.toString() ?? '';
                final contactId = visit['contactId']?.toString() ??
                    visit['contactName']?.toString() ??
                    '--';
                final seq = (visit['sequence'] as num?)?.toInt() ??
                    (visit['sequenceNumber'] as num?)?.toInt();
                final visitStatus =
                    visit['status']?.toString() ?? 'PLANNED';
                final checkInTime = visit['checkInTime']?.toString();
                final checkOutTime = visit['checkOutTime']?.toString();
                final orderValue =
                    (visit['orderValue'] as num?)?.toDouble();
                final collectionAmount =
                    (visit['collectionAmount'] as num?)?.toDouble();
                final skipReason = visit['skipReason']?.toString();

                return Padding(
                  padding: const EdgeInsets.only(bottom: KSpacing.sm),
                  child: KCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (seq != null) ...[
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: _visitStatusColor(visitStatus)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text('$seq',
                                      style: KTypography.labelMedium.copyWith(
                                          color: _visitStatusColor(
                                              visitStatus))),
                                ),
                              ),
                              KSpacing.hGapSm,
                            ],
                            Expanded(
                              child: Text('Contact: $contactId',
                                  style: KTypography.bodyMedium),
                            ),
                            KStatusChip(
                              status: visitStatus,
                              label: visitStatus.replaceAll('_', ' '),
                            ),
                          ],
                        ),

                        // -- Completed visit details --
                        if (visitStatus == 'COMPLETED') ...[
                          KSpacing.vGapSm,
                          if (checkInTime != null)
                            Text('Check-in: $checkInTime',
                                style: KTypography.bodySmall.copyWith(
                                    color: KColors.textSecondary)),
                          if (checkOutTime != null)
                            Text('Check-out: $checkOutTime',
                                style: KTypography.bodySmall.copyWith(
                                    color: KColors.textSecondary)),
                          if (orderValue != null)
                            Text(
                                'Order: ${CurrencyFormatter.formatIndian(orderValue)}',
                                style: KTypography.bodySmall),
                          if (collectionAmount != null)
                            Text(
                                'Collection: ${CurrencyFormatter.formatIndian(collectionAmount)}',
                                style: KTypography.bodySmall),
                        ],

                        // -- Skipped visit details --
                        if (visitStatus == 'SKIPPED' &&
                            skipReason != null) ...[
                          KSpacing.vGapSm,
                          Text('Reason: $skipReason',
                              style: KTypography.bodySmall
                                  .copyWith(color: KColors.error)),
                        ],

                        // -- Action buttons --
                        KSpacing.vGapSm,
                        Wrap(
                          spacing: KSpacing.sm,
                          runSpacing: KSpacing.xs,
                          children: [
                            if (visitStatus == 'PLANNED') ...[
                              FilledButton.tonal(
                                onPressed: () => _checkIn(visitId),
                                child: const Text('Check In'),
                              ),
                              OutlinedButton(
                                onPressed: () => _showSkipDialog(visitId),
                                child: const Text('Skip'),
                              ),
                            ],
                            if (visitStatus == 'IN_PROGRESS') ...[
                              FilledButton.tonal(
                                onPressed: () => _checkOut(visitId),
                                child: const Text('Check Out'),
                              ),
                              OutlinedButton(
                                onPressed: () =>
                                    _showRecordOrderDialog(visitId),
                                child: const Text('Record Order'),
                              ),
                              OutlinedButton(
                                onPressed: () =>
                                    _showRecordCollectionDialog(visitId),
                                child: const Text('Record Collection'),
                              ),
                            ],
                            if (visitStatus == 'COMPLETED') ...[
                              OutlinedButton(
                                onPressed: () =>
                                    _showRecordOrderDialog(visitId),
                                child: const Text('Record Order'),
                              ),
                              OutlinedButton(
                                onPressed: () =>
                                    _showRecordCollectionDialog(visitId),
                                child: const Text('Record Collection'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
      bottomNavigationBar: (status == 'IN_PROGRESS' || status == 'COMPLETED')
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Row(
                  children: [
                    if (status == 'IN_PROGRESS')
                      Expanded(
                        child: FilledButton(
                          onPressed: _completeRoute,
                          child: const Text('Complete Route'),
                        ),
                      ),
                    if (status == 'COMPLETED')
                      Expanded(
                        child: FilledButton(
                          onPressed: () => context.push(
                              '/field-sales/day-close?executionId=${widget.executionId}'),
                          child: const Text('Day Close'),
                        ),
                      ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 100),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: KTypography.labelMedium.copyWith(color: color)),
        ],
      ),
    );
  }
}
