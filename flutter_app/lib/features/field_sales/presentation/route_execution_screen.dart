import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/field_sales_repository.dart';

class RouteExecutionScreen extends ConsumerStatefulWidget {
  const RouteExecutionScreen({super.key});

  @override
  ConsumerState<RouteExecutionScreen> createState() =>
      _RouteExecutionScreenState();
}

class _RouteExecutionScreenState extends ConsumerState<RouteExecutionScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _executions = [];
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadExecutions();
  }

  Future<void> _loadExecutions() async {
    setState(() => _isLoading = true);
    try {
      final dateStr = _selectedDate.toIso8601String().split('T')[0];
      final executions = await ref
          .read(fieldSalesRepositoryProvider)
          .listExecutions(date: dateStr);
      if (mounted) setState(() => _executions = executions);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load executions: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _loadExecutions();
    }
  }

  Future<void> _showCreateDialog() async {
    final routeIdCtl = TextEditingController();
    final salespersonIdCtl = TextEditingController();
    final vanIdCtl = TextEditingController();
    final dateCtl = TextEditingController(
      text: _selectedDate.toIso8601String().split('T')[0],
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Execution'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: routeIdCtl,
                decoration: const InputDecoration(
                  labelText: 'Route ID *',
                  hintText: 'Enter route ID',
                ),
              ),
              KSpacing.vGapSm,
              TextField(
                controller: salespersonIdCtl,
                decoration: const InputDecoration(
                  labelText: 'Salesperson ID *',
                  hintText: 'Enter salesperson ID',
                ),
              ),
              KSpacing.vGapSm,
              TextField(
                controller: vanIdCtl,
                decoration: const InputDecoration(
                  labelText: 'Van ID',
                  hintText: 'Optional',
                ),
              ),
              KSpacing.vGapSm,
              TextField(
                controller: dateCtl,
                decoration: const InputDecoration(
                  labelText: 'Date *',
                  hintText: 'YYYY-MM-DD',
                ),
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
            onPressed: () {
              if (routeIdCtl.text.trim().isEmpty ||
                  salespersonIdCtl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Route ID and Salesperson ID are required')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(fieldSalesRepositoryProvider).createExecution({
        'routeId': routeIdCtl.text.trim(),
        'salespersonId': salespersonIdCtl.text.trim(),
        if (vanIdCtl.text.trim().isNotEmpty) 'vanId': vanIdCtl.text.trim(),
        'date': dateCtl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Execution created successfully'),
            backgroundColor: KColors.success,
          ),
        );
      }
      await _loadExecutions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create execution: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _startExecution(String id) async {
    try {
      await ref.read(fieldSalesRepositoryProvider).startExecution(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route started'),
            backgroundColor: KColors.success,
          ),
        );
      }
      await _loadExecutions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start route: $e')),
        );
      }
    }
  }

  Future<void> _completeExecution(String id) async {
    try {
      await ref.read(fieldSalesRepositoryProvider).completeExecution(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route completed'),
            backgroundColor: KColors.success,
          ),
        );
      }
      await _loadExecutions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete route: $e')),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.green;
      case 'PLANNED':
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _selectedDate.toIso8601String().split('T')[0];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Routes"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Pick date',
            onPressed: _pickDate,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: KSpacing.md, vertical: KSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.event, size: 16, color: KColors.textSecondary),
                const SizedBox(width: 6),
                Text(dateStr,
                    style: KTypography.labelMedium
                        .copyWith(color: KColors.textSecondary)),
                const Spacer(),
                Text('${_executions.length} execution(s)',
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.textSecondary)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const KLoading()
                : _executions.isEmpty
                    ? KEmptyState(
                        icon: Icons.directions_walk_outlined,
                        title: 'No executions for this date',
                        subtitle:
                            'Create a route execution to plan field visits.',
                      )
                    : RefreshIndicator(
                        onRefresh: _loadExecutions,
                        child: ListView.separated(
                          padding: KSpacing.pagePadding,
                          itemCount: _executions.length,
                          separatorBuilder: (_, __) => KSpacing.vGapSm,
                          itemBuilder: (context, index) {
                            final exec = _executions[index];
                            final id = exec['id']?.toString() ?? '';
                            final status =
                                exec['status']?.toString() ?? 'PLANNED';
                            final routeName =
                                exec['routeName']?.toString() ??
                                    exec['routeId']?.toString() ??
                                    '--';
                            final salesperson =
                                exec['salespersonName']?.toString() ??
                                    exec['salespersonId']?.toString() ??
                                    '--';
                            final totalVisits =
                                (exec['totalVisits'] as num?)?.toInt() ?? 0;
                            final completedVisits =
                                (exec['completedVisits'] as num?)?.toInt() ??
                                    0;
                            final ordersValue =
                                (exec['ordersValue'] as num?)?.toDouble() ??
                                    0;
                            final collections =
                                (exec['collections'] as num?)?.toDouble() ??
                                    0;

                            return KCard(
                              onTap: () => context
                                  .push('/field-sales/executions/$id'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(routeName,
                                            style: KTypography.labelLarge,
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                      KSpacing.hGapSm,
                                      KStatusChip(
                                        status: status,
                                        label: status.replaceAll('_', ' '),
                                      ),
                                    ],
                                  ),
                                  KSpacing.vGapXs,
                                  Text('Salesperson: $salesperson',
                                      style: KTypography.bodySmall.copyWith(
                                          color: KColors.textSecondary)),
                                  KSpacing.vGapSm,
                                  Row(
                                    children: [
                                      _MetricChip(
                                          label:
                                              '$completedVisits/$totalVisits visits'),
                                      KSpacing.hGapMd,
                                      _MetricChip(
                                          label: CurrencyFormatter
                                              .formatIndian(ordersValue),
                                          icon: Icons.receipt_long_outlined),
                                      KSpacing.hGapMd,
                                      _MetricChip(
                                          label: CurrencyFormatter
                                              .formatIndian(collections),
                                          icon: Icons.payments_outlined),
                                    ],
                                  ),
                                  KSpacing.vGapSm,
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (status == 'PLANNED')
                                        FilledButton.tonal(
                                          onPressed: () =>
                                              _startExecution(id),
                                          child: const Text('Start Route'),
                                        ),
                                      if (status == 'IN_PROGRESS')
                                        FilledButton.tonal(
                                          onPressed: () =>
                                              _completeExecution(id),
                                          child: const Text('Complete'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Execution'),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _MetricChip({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: KColors.textSecondary),
          const SizedBox(width: 3),
        ],
        Flexible(
          child: Text(label,
              style: KTypography.bodySmall
                  .copyWith(color: KColors.textSecondary),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
