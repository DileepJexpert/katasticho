import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
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

  bool get _canManageRoutes {
    final role = ref.read(authProvider).role?.toUpperCase();
    return role == 'OWNER' || role == 'ADMIN';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repository = ref.read(fieldSalesRepositoryProvider);
      final results = await Future.wait([
        repository.listRoutes(),
        repository.listBeats(size: 200),
      ]);
      if (mounted) {
        setState(() {
          _routes = results[0];
          _beats = results[1];
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load routes: ${ApiErrorParser.message(error)}'),
            backgroundColor: KColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openRouteEditor([Map<String, dynamic>? route]) async {
    if (!_canManageRoutes) return;

    final routeId = route?['id']?.toString();
    List<Map<String, dynamic>> routeBeats = [];
    if (routeId != null && routeId.isNotEmpty) {
      try {
        routeBeats = await ref.read(fieldSalesRepositoryProvider).getRouteBeats(routeId);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not load the route beat plan: ${ApiErrorParser.message(error)}'),
              backgroundColor: KColors.error,
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _RouteEditorDialog(
        route: route,
        beats: _beats,
        routeBeats: routeBeats,
      ),
    );
    if (payload == null || !mounted) return;

    try {
      final repository = ref.read(fieldSalesRepositoryProvider);
      if (routeId == null || routeId.isEmpty) {
        await repository.createRoute(payload);
      } else {
        await repository.updateRoute(routeId, payload);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(routeId == null ? 'Route created' : 'Route updated'),
          backgroundColor: KColors.success,
        ),
      );
      await _loadData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save route: ${ApiErrorParser.message(error)}'),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(authProvider.select((state) {
      final role = state.role?.toUpperCase();
      return role == 'OWNER' || role == 'ADMIN';
    }));

    return KKeyboardListWrapper(
      itemCount: () => _routes.length,
      onNew: canManage ? () => _openRouteEditor() : null,
      onRefresh: _loadData,
      child: Scaffold(
        appBar: AppBar(title: const Text('Routes')),
        body: _isLoading
            ? const KLoading()
            : _routes.isEmpty
                ? KEmptyState(
                    icon: Icons.route_outlined,
                    title: 'No routes yet',
                    subtitle: 'Create routes to plan daily field visits for your sales team.',
                    actionLabel: canManage ? 'New Route' : null,
                    onAction: canManage ? () => _openRouteEditor() : null,
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.separated(
                      padding: KSpacing.pagePadding,
                      itemCount: _routes.length,
                      separatorBuilder: (_, __) => KSpacing.vGapSm,
                      itemBuilder: (context, index) => _RouteCard(
                        route: _routes[index],
                        canManage: canManage,
                        onEdit: () => _openRouteEditor(_routes[index]),
                      ),
                    ),
                  ),
        floatingActionButton: canManage
            ? FloatingActionButton.extended(
                backgroundColor: KColors.primary,
                foregroundColor: Colors.white,
                onPressed: () => _openRouteEditor(),
                icon: const Icon(Icons.add),
                label: const Text('New Route'),
                tooltip: 'New Route (N)',
              )
            : null,
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.canManage,
    required this.onEdit,
  });

  final Map<String, dynamic> route;
  final bool canManage;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final code = route['code']?.toString() ?? '--';
    final name = route['name']?.toString() ?? 'Unnamed Route';
    final dayOfWeek = route['dayOfWeek']?.toString() ?? '';
    final frequency = route['frequency']?.toString() ?? '';
    final beatCount = (route['beatCount'] as num?)?.toInt() ??
        (route['beats'] is List ? (route['beats'] as List).length : 0);
    final active = route['active'] != false;

    String titleCase(String value) => value.isEmpty
        ? ''
        : value[0] + value.substring(1).toLowerCase();

    return KCard(
      statusAccent: active ? KColors.primary : null,
      leading: Icon(
        Icons.route_outlined,
        color: active ? KColors.primary : KColors.textSecondary,
      ),
      title: name,
      subtitleWidget: Text(
        code,
        style: KTypography.mono(
          fontSize: 12,
          color: KColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!active)
            const KStatusChip(status: 'INACTIVE', label: 'Inactive')
          else
            const KStatusChip(status: 'ACTIVE', label: 'Active'),
          if (canManage) ...[
            KSpacing.hGapSm,
            KButton.outlined(
              label: 'Edit',
              icon: Icons.edit_outlined,
              size: KButtonSize.small,
              onPressed: onEdit,
            ),
          ],
        ],
      ),
      child: Wrap(
        spacing: KSpacing.md,
        runSpacing: KSpacing.xs,
        children: [
          _RouteDetail(icon: Icons.calendar_today_outlined, label: titleCase(dayOfWeek)),
          _RouteDetail(icon: Icons.repeat_outlined, label: titleCase(frequency)),
          _RouteDetail(
            icon: Icons.map_outlined,
            label: '$beatCount beat${beatCount == 1 ? '' : 's'}',
          ),
        ],
      ),
    );
  }
}

class _RouteDetail extends StatelessWidget {
  const _RouteDetail({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: KColors.textSecondary),
        KSpacing.hGapXs,
        Text(label, style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
      ],
    );
  }
}

class _RouteEditorDialog extends StatefulWidget {
  const _RouteEditorDialog({
    this.route,
    required this.beats,
    required this.routeBeats,
  });

  final Map<String, dynamic>? route;
  final List<Map<String, dynamic>> beats;
  final List<Map<String, dynamic>> routeBeats;

  @override
  State<_RouteEditorDialog> createState() => _RouteEditorDialogState();
}

class _RouteEditorDialogState extends State<_RouteEditorDialog> {
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _warehouseController;
  late final TextEditingController _beatSearchController;
  late final LinkedHashSet<String> _selectedBeatIds;
  String _selectedDay = 'MONDAY';
  String _selectedFrequency = 'WEEKLY';
  String _beatQuery = '';

  static const _daysOfWeek = [
    'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY',
  ];
  static const _frequencies = ['DAILY', 'WEEKLY', 'BIWEEKLY', 'MONTHLY'];

  @override
  void initState() {
    super.initState();
    final route = widget.route;
    _codeController = TextEditingController(text: route?['code']?.toString());
    _nameController = TextEditingController(text: route?['name']?.toString());
    _warehouseController = TextEditingController(text: route?['warehouseId']?.toString());
    _beatSearchController = TextEditingController();
    _selectedDay = route?['dayOfWeek']?.toString() ?? _selectedDay;
    _selectedFrequency = route?['frequency']?.toString() ?? _selectedFrequency;
    _selectedBeatIds = LinkedHashSet.of(
      widget.routeBeats
          .map((routeBeat) => routeBeat['beatId']?.toString())
          .whereType<String>(),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _warehouseController.dispose();
    _beatSearchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _visibleBeats {
    if (_beatQuery.trim().isEmpty) return widget.beats;
    final query = _beatQuery.toLowerCase();
    return widget.beats.where((beat) {
      final value = '${beat['name'] ?? ''} ${beat['code'] ?? ''} ${beat['area'] ?? ''}';
      return value.toLowerCase().contains(query);
    }).toList();
  }

  String _titleCase(String value) => value[0] + value.substring(1).toLowerCase();

  void _save() {
    final code = _codeController.text.trim();
    final name = _nameController.text.trim();
    if (code.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route code and name are required.')),
      );
      return;
    }
    Navigator.pop(context, {
      'code': code,
      'name': name,
      'dayOfWeek': _selectedDay,
      'frequency': _selectedFrequency,
      'warehouseId': _warehouseController.text.trim().isEmpty
          ? null
          : _warehouseController.text.trim(),
      'beatIds': _selectedBeatIds.toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.route != null;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
        child: Padding(
          padding: KSpacing.pagePaddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(editing ? 'Edit Route' : 'New Route', style: KTypography.titleLarge),
              KSpacing.vGapMd,
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      KTextField(
                        label: 'Route code',
                        hint: 'e.g. GONDA-MAIN-01',
                        controller: _codeController,
                        isRequired: true,
                        readOnly: editing,
                      ),
                      KSpacing.vGapSm,
                      KTextField(
                        label: 'Route name',
                        hint: 'e.g. Gonda Main Market Route',
                        controller: _nameController,
                        isRequired: true,
                      ),
                      KSpacing.vGapSm,
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedDay,
                              decoration: const InputDecoration(labelText: 'Scheduled day'),
                              items: _daysOfWeek.map((day) => DropdownMenuItem(
                                value: day,
                                child: Text(_titleCase(day)),
                              )).toList(),
                              onChanged: (value) => setState(() => _selectedDay = value ?? _selectedDay),
                            ),
                          ),
                          KSpacing.hGapSm,
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedFrequency,
                              decoration: const InputDecoration(labelText: 'Frequency'),
                              items: _frequencies.map((frequency) => DropdownMenuItem(
                                value: frequency,
                                child: Text(_titleCase(frequency)),
                              )).toList(),
                              onChanged: (value) => setState(() => _selectedFrequency = value ?? _selectedFrequency),
                            ),
                          ),
                        ],
                      ),
                      KSpacing.vGapSm,
                      KTextField(
                        label: 'Warehouse ID',
                        hint: 'Optional fulfilment warehouse',
                        controller: _warehouseController,
                      ),
                      KSpacing.vGapMd,
                      KCard(
                        title: 'Beat plan',
                        subtitle: _selectedBeatIds.isEmpty
                            ? 'No beats selected'
                            : '${_selectedBeatIds.length} beat${_selectedBeatIds.length == 1 ? '' : 's'} in visit order',
                        child: Column(
                          children: [
                            KTextField.search(
                              controller: _beatSearchController,
                              hint: 'Search available beats',
                              onChanged: (value) => setState(() => _beatQuery = value),
                              onClear: () {
                                _beatSearchController.clear();
                                setState(() => _beatQuery = '');
                              },
                            ),
                            KSpacing.vGapSm,
                            SizedBox(
                              height: 220,
                              child: _visibleBeats.isEmpty
                                  ? Center(
                                      child: Text(
                                        'No matching beats',
                                        style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: _visibleBeats.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final beat = _visibleBeats[index];
                                        final beatId = beat['id']?.toString() ?? '';
                                        final selected = _selectedBeatIds.contains(beatId);
                                        return CheckboxListTile(
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          value: selected,
                                          title: Text(beat['name']?.toString() ?? 'Unnamed beat'),
                                          subtitle: Text(beat['code']?.toString() ?? ''),
                                          onChanged: beatId.isEmpty ? null : (value) {
                                            setState(() {
                                              if (value == true) {
                                                _selectedBeatIds.add(beatId);
                                              } else {
                                                _selectedBeatIds.remove(beatId);
                                              }
                                            });
                                          },
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              KSpacing.vGapMd,
              Row(
                children: [
                  Expanded(
                    child: KButton.outlined(
                      label: 'Cancel',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  KSpacing.hGapSm,
                  Expanded(
                    child: KButton.primary(
                      label: editing ? 'Save changes' : 'Create Route',
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
