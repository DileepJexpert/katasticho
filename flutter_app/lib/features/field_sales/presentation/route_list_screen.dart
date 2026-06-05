import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/field_sales_repository.dart';

class RouteListScreen extends ConsumerStatefulWidget {
  const RouteListScreen({super.key});

  @override
  ConsumerState<RouteListScreen> createState() => _RouteListScreenState();
}

class _RouteListScreenState extends ConsumerState<RouteListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _routes = [];
  List<Map<String, dynamic>> _beats = [];

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
        repo.listRoutes(),
        repo.listBeats(),
      ]);
      if (mounted) {
        setState(() {
          _routes = results[0];
          _beats = results[1];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load routes: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showCreateRouteDialog() async {
    final codeCtl = TextEditingController();
    final nameCtl = TextEditingController();
    final warehouseCtl = TextEditingController();
    String selectedDay = 'MONDAY';
    String selectedFrequency = 'WEEKLY';
    final Set<String> selectedBeatIds = {};

    final daysOfWeek = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY',
    ];
    final frequencies = ['DAILY', 'WEEKLY', 'BIWEEKLY', 'MONTHLY'];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Route'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: codeCtl,
                  decoration: const InputDecoration(
                    labelText: 'Code *',
                    hintText: 'e.g. RT-001',
                  ),
                ),
                KSpacing.vGapSm,
                TextField(
                  controller: nameCtl,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    hintText: 'e.g. North Zone Route',
                  ),
                ),
                KSpacing.vGapSm,
                DropdownButtonFormField<String>(
                  value: selectedDay,
                  decoration: const InputDecoration(labelText: 'Day of Week'),
                  items: daysOfWeek
                      .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(d[0] + d.substring(1).toLowerCase())))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedDay = val);
                    }
                  },
                ),
                KSpacing.vGapSm,
                DropdownButtonFormField<String>(
                  value: selectedFrequency,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: frequencies
                      .map((f) => DropdownMenuItem(
                          value: f,
                          child: Text(f[0] + f.substring(1).toLowerCase())))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedFrequency = val);
                    }
                  },
                ),
                KSpacing.vGapSm,
                TextField(
                  controller: warehouseCtl,
                  decoration: const InputDecoration(
                    labelText: 'Warehouse ID',
                    hintText: 'Optional',
                  ),
                ),
                KSpacing.vGapMd,
                Text('Select Beats', style: KTypography.labelMedium),
                KSpacing.vGapXs,
                if (_beats.isEmpty)
                  Text('No beats available',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary))
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: SingleChildScrollView(
                      child: Column(
                        children: _beats.map((beat) {
                          final id = beat['id']?.toString() ?? '';
                          final beatName =
                              beat['name']?.toString() ?? 'Unnamed';
                          final isSelected = selectedBeatIds.contains(id);
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(beatName,
                                style: KTypography.bodyMedium),
                            subtitle: Text(
                                beat['code']?.toString() ?? '',
                                style: KTypography.bodySmall),
                            value: isSelected,
                            onChanged: (val) {
                              setDialogState(() {
                                if (val == true) {
                                  selectedBeatIds.add(id);
                                } else {
                                  selectedBeatIds.remove(id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
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
                if (codeCtl.text.trim().isEmpty ||
                    nameCtl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Code and Name are required')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(fieldSalesRepositoryProvider).createRoute({
        'code': codeCtl.text.trim(),
        'name': nameCtl.text.trim(),
        'dayOfWeek': selectedDay,
        'frequency': selectedFrequency,
        if (warehouseCtl.text.trim().isNotEmpty)
          'warehouseId': warehouseCtl.text.trim(),
        if (selectedBeatIds.isNotEmpty) 'beatIds': selectedBeatIds.toList(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route created successfully'),
            backgroundColor: KColors.success,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create route: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Routes'),
      ),
      body: _isLoading
          ? const KLoading()
          : _routes.isEmpty
              ? KEmptyState(
                  icon: Icons.route_outlined,
                  title: 'No routes yet',
                  subtitle:
                      'Create routes to plan daily field visits for your sales team.',
                  actionLabel: 'New Route',
                  onAction: _showCreateRouteDialog,
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.separated(
                    padding: KSpacing.pagePadding,
                    itemCount: _routes.length,
                    separatorBuilder: (_, __) => KSpacing.vGapSm,
                    itemBuilder: (context, index) {
                      final route = _routes[index];
                      return _RouteCard(route: route);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateRouteDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Route'),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final Map<String, dynamic> route;

  const _RouteCard({required this.route});

  @override
  Widget build(BuildContext context) {
    final code = route['code']?.toString() ?? '--';
    final name = route['name']?.toString() ?? 'Unnamed Route';
    final dayOfWeek = route['dayOfWeek']?.toString() ?? '';
    final frequency = route['frequency']?.toString() ?? '';
    final estimatedDistance =
        (route['estimatedDistanceKm'] as num?)?.toDouble();
    final beatCount = (route['beatCount'] as num?)?.toInt() ??
        (route['beats'] is List ? (route['beats'] as List).length : 0);
    final active = route['active'] != false;

    final dayLabel = dayOfWeek.isNotEmpty
        ? dayOfWeek[0] + dayOfWeek.substring(1).toLowerCase()
        : '';
    final freqLabel = frequency.isNotEmpty
        ? frequency[0] + frequency.substring(1).toLowerCase()
        : '';

    return KCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (active ? KColors.info : KColors.textSecondary)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.route_outlined,
                color: active ? KColors.info : KColors.textSecondary,
                size: 20),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(name,
                          style: KTypography.labelLarge,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (!active) ...[
                      KSpacing.hGapSm,
                      KStatusChip(
                          status: 'INACTIVE', label: 'Inactive'),
                    ],
                  ],
                ),
                KSpacing.vGapXs,
                Text(code,
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.textSecondary)),
                KSpacing.vGapXs,
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (dayLabel.isNotEmpty)
                      _InfoChip(
                          icon: Icons.calendar_today,
                          label: dayLabel),
                    if (freqLabel.isNotEmpty)
                      _InfoChip(
                          icon: Icons.repeat, label: freqLabel),
                    if (estimatedDistance != null)
                      _InfoChip(
                          icon: Icons.straighten,
                          label: '${estimatedDistance.toStringAsFixed(1)} km'),
                    _InfoChip(
                        icon: Icons.map_outlined,
                        label:
                            '$beatCount beat${beatCount == 1 ? '' : 's'}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: KColors.textSecondary),
        const SizedBox(width: 3),
        Text(label,
            style:
                KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
      ],
    );
  }
}
