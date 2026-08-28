import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/field_sales_repository.dart';

/// Admin-only screen to manage Salesperson-to-Route, Van, and Territory assignments.
class TeamAssignmentsScreen extends ConsumerStatefulWidget {
  const TeamAssignmentsScreen({super.key});

  @override
  ConsumerState<TeamAssignmentsScreen> createState() =>
      _TeamAssignmentsScreenState();
}

class _TeamAssignmentsScreenState
    extends ConsumerState<TeamAssignmentsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _routes = [];
  List<Map<String, dynamic>> _vans = [];
  String _searchQuery = '';
  bool _showInactive = false;
  final _searchController = TextEditingController();

  Dio get _dio => ref.read(apiClientProvider).dio;
  FieldSalesRepository get _repo => ref.read(fieldSalesRepositoryProvider);

  bool get _canManage {
    final role = ref.read(authProvider).role?.toUpperCase();
    return role == 'OWNER' || role == 'ADMIN';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.listAssignments(includeInactive: _showInactive),
        _repo.listRoutes(),
        _repo.listVans(),
        _fetchOrgUsers(),
      ]);

      if (mounted) {
        setState(() {
          _assignments = results[0];
          _routes = results[1];
          _vans = results[2];
          _users = results[3];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchOrgUsers() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(ApiConfig.orgUsers);
      final data =
          (resp.data?['data'] as List?) ?? (resp.data as List? ?? []);
      return data
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }

  String _userId(Map<String, dynamic> u) {
    return (u['userId'] ?? u['id'])?.toString() ?? '';
  }

  String _userName(String? id) {
    if (id == null || id.isEmpty) return '—';
    final u = _users.firstWhere(
      (e) => _userId(e) == id,
      orElse: () => <String, dynamic>{},
    );
    return (u['fullName'] ?? u['displayName'] ?? u['name'] ?? u['email'] ?? id)
        .toString();
  }

  String _routeName(String? id) {
    if (id == null || id.isEmpty) return '—';
    final r = _routes.firstWhere(
      (e) => e['id']?.toString() == id,
      orElse: () => <String, dynamic>{},
    );
    final name = r['name']?.toString();
    final code = r['code']?.toString();
    if (name != null && code != null) return '$name ($code)';
    return name ?? code ?? id;
  }

  String _vanName(String? id) {
    if (id == null || id.isEmpty) return '—';
    final v = _vans.firstWhere(
      (e) => e['id']?.toString() == id,
      orElse: () => <String, dynamic>{},
    );
    final reg = v['registrationNumber']?.toString();
    final name = v['vanName']?.toString();
    if (reg != null && name != null) return '$name [$reg]';
    return reg ?? name ?? id;
  }

  /// Calculates assignment temporal status: Active, Upcoming, Expired, Terminated.
  _AssignmentStatus _evalStatus(Map<String, dynamic> a) {
    final isActive = a['isActive'] != false;
    if (!isActive) return _AssignmentStatus.terminated;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final fromStr = a['effectiveFrom']?.toString();
    final toStr = a['effectiveTo']?.toString();

    if (fromStr != null) {
      final fromDate = DateTime.tryParse(fromStr);
      if (fromDate != null && fromDate.isAfter(todayDate)) {
        return _AssignmentStatus.upcoming;
      }
    }

    if (toStr != null) {
      final toDate = DateTime.tryParse(toStr);
      if (toDate != null && toDate.isBefore(todayDate)) {
        return _AssignmentStatus.expired;
      }
    }

    return _AssignmentStatus.active;
  }

  List<Map<String, dynamic>> get _filteredAssignments {
    if (_searchQuery.trim().isEmpty) return _assignments;
    final q = _searchQuery.trim().toLowerCase();
    return _assignments.where((a) {
      final sp = _userName(a['salespersonId']?.toString()).toLowerCase();
      final rt = _routeName(a['routeId']?.toString()).toLowerCase();
      final vn = _vanName(a['vanId']?.toString()).toLowerCase();
      final territory = (a['territory']?.toString() ?? '').toLowerCase();
      return sp.contains(q) || rt.contains(q) || vn.contains(q) || territory.contains(q);
    }).toList();
  }

  Future<void> _openCreateDialog() async {
    if (!_canManage) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _AssignmentEditorDialog(
        users: _users,
        routes: _routes,
        vans: _vans,
      ),
    );

    if (result == null || !mounted) return;

    try {
      await _repo.createAssignment(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Team assignment created successfully'),
            backgroundColor: KColors.success,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create assignment: $e'),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }

  Future<void> _openEditDialog(Map<String, dynamic> assignment) async {
    if (!_canManage) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _AssignmentEditorDialog(
        initial: assignment,
        users: _users,
        routes: _routes,
        vans: _vans,
      ),
    );

    if (result == null || !mounted) return;

    final id = assignment['id']?.toString();
    if (id == null) return;

    try {
      await _repo.updateAssignment(id, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment updated successfully'),
            backgroundColor: KColors.success,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update assignment: $e'),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }

  Future<void> _endAssignment(Map<String, dynamic> assignment) async {
    if (!_canManage) return;
    final spName = _userName(assignment['salespersonId']?.toString());
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Assignment'),
        content: Text('End active assignment for $spName as of today?'),
        actions: [
          KButton.outlined(
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, false),
            label: 'Cancel',
          ),
          KSpacing.hGapSm,
          KButton.secondary(
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, true),
            label: 'End Assignment',
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final id = assignment['id']?.toString();
    if (id == null) return;

    try {
      await _repo.endAssignment(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment ended'),
            backgroundColor: KColors.success,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to end assignment: $e'),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deactivateAssignment(Map<String, dynamic> assignment) async {
    if (!_canManage) return;
    final spName = _userName(assignment['salespersonId']?.toString());
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Assignment'),
        content: Text('Are you sure you want to deactivate the assignment for $spName? Historical records will be preserved.'),
        actions: [
          KButton.outlined(
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, false),
            label: 'Cancel',
          ),
          KSpacing.hGapSm,
          KButton.danger(
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, true),
            label: 'Deactivate',
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final id = assignment['id']?.toString();
    if (id == null) return;

    try {
      await _repo.deleteAssignment(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment deactivated'),
            backgroundColor: KColors.success,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to deactivate assignment: $e'),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAssignments;
    final activeList = _assignments.where((a) => _evalStatus(a) == _AssignmentStatus.active).toList();
    final uniqueSalespersons =
        activeList.map((a) => a['salespersonId']?.toString()).whereType<String>().toSet().length;
    final uniqueRoutes =
        activeList.map((a) => a['routeId']?.toString()).whereType<String>().toSet().length;
    final uniqueVans =
        activeList.map((a) => a['vanId']?.toString()).whereType<String>().toSet().length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Assignments'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
          ),
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              backgroundColor: KColors.primary,
              foregroundColor: Colors.white,
              onPressed: _openCreateDialog,
              icon: const Icon(Icons.add),
              label: const Text('New Assignment'),
              tooltip: 'New Assignment (N)',
            )
          : null,
      body: _isLoading
          ? const Center(child: KLoading())
          : _error != null
              ? KErrorView(message: _error!, onRetry: _loadData)
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: KSpacing.pagePadding,
                    children: [
                      // -- Metric Summary Strip --
                      Wrap(
                        spacing: KSpacing.sm,
                        runSpacing: KSpacing.sm,
                        children: [
                          _MetricCard(
                            label: 'Active Assignments',
                            value: '${activeList.length}',
                            color: KColors.primary,
                            icon: Icons.assignment_ind_outlined,
                          ),
                          _MetricCard(
                            label: 'Active Sales Team',
                            value: '$uniqueSalespersons',
                            color: KColors.info,
                            icon: Icons.people_outline,
                          ),
                          _MetricCard(
                            label: 'Routes Covered',
                            value: '$uniqueRoutes',
                            color: KColors.success,
                            icon: Icons.route_outlined,
                          ),
                          _MetricCard(
                            label: 'Vans Assigned',
                            value: '$uniqueVans',
                            color: KColors.warning,
                            icon: Icons.local_shipping_outlined,
                          ),
                        ],
                      ),
                      KSpacing.vGapMd,

                      // -- Search & Controls --
                      Row(
                        children: [
                          Expanded(
                            child: KTextField.search(
                              controller: _searchController,
                              hint: 'Search by salesperson, route, van, or territory...',
                              onChanged: (v) => setState(() => _searchQuery = v),
                              onClear: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                          ),
                          KSpacing.hGapSm,
                          FilterChip(
                            label: const Text('Show Inactive'),
                            selected: _showInactive,
                            onSelected: (val) {
                              setState(() => _showInactive = val);
                              _loadData();
                            },
                          ),
                          if (_canManage) ...[
                            KSpacing.hGapSm,
                            KButton.primary(
                              label: 'New Assignment',
                              icon: Icons.add,
                              onPressed: _openCreateDialog,
                            ),
                          ],
                        ],
                      ),
                      KSpacing.vGapMd,

                      // -- Content --
                      if (filtered.isEmpty)
                        KCard(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                _assignments.isEmpty
                                    ? 'No team assignments found. Assign a salesperson to a route to get started.'
                                    : 'No assignments matching "$_searchQuery".',
                                style: KTypography.bodyMedium
                                    .copyWith(color: KColors.textSecondary),
                              ),
                            ),
                          ),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth >= KSpacing.tabletBreakpoint) {
                              return KDataTable(
                                columns: [
                                  const KTableColumn(label: 'Salesperson'),
                                  const KTableColumn(label: 'Route'),
                                  const KTableColumn(label: 'Van'),
                                  const KTableColumn(label: 'Territory'),
                                  const KTableColumn(label: 'Effective Period'),
                                  const KTableColumn(label: 'Status'),
                                  if (_canManage) const KTableColumn(label: 'Actions'),
                                ],
                                rows: filtered.map((a) {
                                  final spName = _userName(a['salespersonId']?.toString());
                                  final rtName = _routeName(a['routeId']?.toString());
                                  final vnName = _vanName(a['vanId']?.toString());
                                  final territory = a['territory']?.toString() ?? '—';
                                  final fromDate = a['effectiveFrom']?.toString() ?? '—';
                                  final toDate = a['effectiveTo']?.toString();
                                  final period = toDate != null ? '$fromDate → $toDate' : 'From $fromDate';
                                  final status = _evalStatus(a);

                                  return [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: KColors.primary.withValues(alpha: 0.1),
                                          child: Text(
                                            spName.isNotEmpty ? spName[0].toUpperCase() : '?',
                                            style: KTypography.mono(fontSize: 10, color: KColors.primary),
                                          ),
                                        ),
                                        KSpacing.hGapSm,
                                        Text(spName, style: KTypography.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    Text(rtName, style: KTypography.bodySmall),
                                    Text(vnName, style: KTypography.bodySmall),
                                    Text(territory, style: KTypography.bodySmall),
                                    Text(period, style: KTypography.bodySmall),
                                    _buildStatusChip(status),
                                    if (_canManage)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 16),
                                            tooltip: 'Edit Assignment',
                                            onPressed: () => _openEditDialog(a),
                                          ),
                                          if (status == _AssignmentStatus.active)
                                            IconButton(
                                              icon: const Icon(Icons.stop_circle_outlined, size: 16, color: KColors.warning),
                                              tooltip: 'End Assignment Today',
                                              onPressed: () => _endAssignment(a),
                                            ),
                                          IconButton(
                                            icon: const Icon(Icons.block_outlined, size: 16, color: KColors.warning),
                                            tooltip: 'Deactivate Assignment',
                                            onPressed: () => _deactivateAssignment(a),
                                          ),
                                        ],
                                      ),
                                  ];
                                }).toList(),
                              );
                            }

                            // Mobile Cards View
                            return Column(
                              children: filtered.map((a) {
                                final spName = _userName(a['salespersonId']?.toString());
                                final rtName = _routeName(a['routeId']?.toString());
                                final vnName = _vanName(a['vanId']?.toString());
                                final territory = a['territory']?.toString();
                                final fromDate = a['effectiveFrom']?.toString() ?? '—';
                                final toDate = a['effectiveTo']?.toString();
                                final period = toDate != null ? '$fromDate → $toDate' : 'From $fromDate';
                                final status = _evalStatus(a);

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: KSpacing.sm),
                                  child: KCard(
                                    statusAccent: status == _AssignmentStatus.active ? KColors.primary : null,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                spName,
                                                style: KTypography.labelLarge
                                                    .copyWith(fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                            _buildStatusChip(status),
                                          ],
                                        ),
                                        KSpacing.vGapSm,
                                        Row(
                                          children: [
                                            const Icon(Icons.route_outlined, size: 16, color: KColors.textSecondary),
                                            KSpacing.hGapXs,
                                            Expanded(
                                              child: Text('Route: $rtName', style: KTypography.bodySmall),
                                            ),
                                          ],
                                        ),
                                        if (vnName != '—') ...[
                                          KSpacing.vGapXs,
                                          Row(
                                            children: [
                                              const Icon(Icons.local_shipping_outlined, size: 16, color: KColors.textSecondary),
                                              KSpacing.hGapXs,
                                              Expanded(
                                                child: Text('Van: $vnName', style: KTypography.bodySmall),
                                              ),
                                            ],
                                          ),
                                        ],
                                        if (territory != null && territory.isNotEmpty) ...[
                                          KSpacing.vGapXs,
                                          Row(
                                            children: [
                                              const Icon(Icons.map_outlined, size: 16, color: KColors.textSecondary),
                                              KSpacing.hGapXs,
                                              Expanded(
                                                child: Text('Territory: $territory', style: KTypography.bodySmall),
                                              ),
                                            ],
                                          ),
                                        ],
                                        KSpacing.vGapXs,
                                        Text(
                                          'Period: $period',
                                          style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                                        ),
                                        if (_canManage) ...[
                                          KSpacing.vGapSm,
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              KButton.outlined(
                                                label: 'Edit',
                                                icon: Icons.edit_outlined,
                                                size: KButtonSize.small,
                                                onPressed: () => _openEditDialog(a),
                                              ),
                                              if (status == _AssignmentStatus.active) ...[
                                                KSpacing.hGapSm,
                                                KButton.outlined(
                                                  label: 'End',
                                                  icon: Icons.stop_circle_outlined,
                                                  size: KButtonSize.small,
                                                  onPressed: () => _endAssignment(a),
                                                ),
                                              ],
                                              KSpacing.hGapSm,
                                              KButton.outlined(
                                                label: 'Deactivate',
                                                icon: Icons.block_outlined,
                                                size: KButtonSize.small,
                                                onPressed: () => _deactivateAssignment(a),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatusChip(_AssignmentStatus status) {
    switch (status) {
      case _AssignmentStatus.active:
        return const KStatusChip(status: 'ACTIVE', label: 'Active');
      case _AssignmentStatus.upcoming:
        return const KStatusChip(status: 'PENDING', label: 'Upcoming');
      case _AssignmentStatus.expired:
        return const KStatusChip(status: 'OVERDUE', label: 'Expired');
      case _AssignmentStatus.terminated:
        return const KStatusChip(status: 'VOIDED', label: 'Terminated');
    }
  }
}

enum _AssignmentStatus {
  active,
  upcoming,
  expired,
  terminated,
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      statusAccent: color,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(label, style: KTypography.labelSmall),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: KTypography.h4.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> routes;
  final List<Map<String, dynamic>> vans;

  const _AssignmentEditorDialog({
    this.initial,
    required this.users,
    required this.routes,
    required this.vans,
  });

  @override
  State<_AssignmentEditorDialog> createState() =>
      _AssignmentEditorDialogState();
}

class _AssignmentEditorDialogState extends State<_AssignmentEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedSalespersonId;
  String? _selectedRouteId;
  String? _selectedVanId;
  final _territoryCtrl = TextEditingController();
  late DateTime _effectiveFrom;
  DateTime? _effectiveTo;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _selectedSalespersonId = init['salespersonId']?.toString();
      _selectedRouteId = init['routeId']?.toString();
      _selectedVanId = init['vanId']?.toString();
      _territoryCtrl.text = init['territory']?.toString() ?? '';
      final fromStr = init['effectiveFrom']?.toString();
      _effectiveFrom = fromStr != null ? (DateTime.tryParse(fromStr) ?? DateTime.now()) : DateTime.now();
      final toStr = init['effectiveTo']?.toString();
      _effectiveTo = toStr != null ? DateTime.tryParse(toStr) : null;
    } else {
      _effectiveFrom = DateTime.now();
    }
  }

  @override
  void dispose() {
    _territoryCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickEffectiveFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _effectiveFrom = picked);
    }
  }

  Future<void> _pickEffectiveTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveTo ?? _effectiveFrom.add(const Duration(days: 90)),
      firstDate: _effectiveFrom,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _effectiveTo = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSalespersonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a salesperson')),
      );
      return;
    }

    final payload = <String, dynamic>{
      'salespersonId': _selectedSalespersonId,
      if (_selectedRouteId != null) 'routeId': _selectedRouteId,
      if (_selectedVanId != null) 'vanId': _selectedVanId,
      if (_territoryCtrl.text.trim().isNotEmpty)
        'territory': _territoryCtrl.text.trim(),
      'effectiveFrom': _fmtDate(_effectiveFrom),
      if (_effectiveTo != null) 'effectiveTo': _fmtDate(_effectiveTo!),
    };

    Navigator.of(context).pop(payload);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Team Assignment' : 'New Team Assignment'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Salesperson Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedSalespersonId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Salesperson *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) => v == null ? 'Required' : null,
                  items: widget.users.map((u) {
                    final id = (u['userId'] ?? u['id'])?.toString() ?? '';
                    final name = (u['fullName'] ?? u['displayName'] ?? u['name'] ?? u['email'] ?? id).toString();
                    return DropdownMenuItem(
                      value: id,
                      child: Text(name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedSalespersonId = v),
                ),
                KSpacing.vGapSm,

                // Route Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedRouteId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Assigned Route',
                    hintText: 'Optional route',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('— None —'),
                    ),
                    ...widget.routes.map((r) {
                      final id = r['id']?.toString() ?? '';
                      final name = r['name']?.toString() ?? 'Unnamed';
                      final code = r['code']?.toString();
                      final label = code != null ? '$name ($code)' : name;
                      return DropdownMenuItem(
                        value: id,
                        child: Text(label, overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() => _selectedRouteId = v),
                ),
                KSpacing.vGapSm,

                // Van Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedVanId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Assigned Van',
                    hintText: 'Optional vehicle',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('— None —'),
                    ),
                    ...widget.vans.map((v) {
                      final id = v['id']?.toString() ?? '';
                      final reg = v['registrationNumber']?.toString() ?? '';
                      final name = v['vanName']?.toString() ?? '';
                      final label = name.isNotEmpty ? '$name [$reg]' : reg;
                      return DropdownMenuItem(
                        value: id,
                        child: Text(label, overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() => _selectedVanId = v),
                ),
                KSpacing.vGapSm,

                // Territory
                TextFormField(
                  controller: _territoryCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Territory',
                    hintText: 'e.g. North Zone / Downtown',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                KSpacing.vGapSm,

                // Dates
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickEffectiveFrom,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Effective From *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          child: Text(_fmtDate(_effectiveFrom)),
                        ),
                      ),
                    ),
                    KSpacing.hGapSm,
                    Expanded(
                      child: InkWell(
                        onTap: _pickEffectiveTo,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Effective To',
                            hintText: 'Ongoing',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: _effectiveTo != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () => setState(() => _effectiveTo = null),
                                  )
                                : null,
                          ),
                          child: Text(_effectiveTo != null ? _fmtDate(_effectiveTo!) : 'Ongoing'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        KButton.outlined(
          size: KButtonSize.small,
          onPressed: () => Navigator.of(context).pop(),
          label: 'Cancel',
        ),
        KSpacing.hGapSm,
        KButton.primary(
          size: KButtonSize.small,
          onPressed: _submit,
          label: isEditing ? 'Save Changes' : 'Assign',
        ),
      ],
    );
  }
}
