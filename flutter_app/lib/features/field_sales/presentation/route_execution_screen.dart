import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
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
    final repo = ref.read(fieldSalesRepositoryProvider);
    final dio = ref.read(apiClientProvider).dio;
    final auth = ref.read(authProvider);
    final role = auth.role?.toUpperCase();
    final isAdmin = role == 'OWNER' || role == 'ADMIN';
    final currentUserId = auth.userId;

    List<Map<String, dynamic>> routes = [];
    List<Map<String, dynamic>> vans = [];
    List<Map<String, dynamic>> users = [];
    List<Map<String, dynamic>> assignments = [];

    final dateStr = _selectedDate.toIso8601String().split('T')[0];

    try {
      if (isAdmin) {
        final results = await Future.wait([
          repo.listRoutes(),
          repo.listVans(),
          repo.listAssignments(includeInactive: false, effectiveOn: dateStr),
          _fetchOrgUsers(dio),
        ]);
        routes = results[0];
        vans = results[1];
        assignments = results[2];
        users = results[3];
      } else {
        // Field Salesperson / Operator view: only fetch own assignments
        final results = await Future.wait([
          repo.listRoutes(),
          repo.listVans(),
          repo.getMyAssignments(effectiveOn: dateStr),
        ]);
        routes = results[0];
        vans = results[1];
        assignments = results[2];
        if (currentUserId != null) {
          users = [
            {
              'id': currentUserId,
              'fullName': auth.userName ?? 'Me',
              'email': null,
            }
          ];
        }
      }
    } catch (_) {
      // Best-effort load
    }

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _CreateExecutionDialog(
        initialDate: _selectedDate,
        routes: routes,
        vans: vans,
        users: users,
        assignments: assignments,
        isAdmin: isAdmin,
        currentUserId: currentUserId,
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await repo.createExecution(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route execution created successfully'),
            backgroundColor: KColors.success,
          ),
        );
        _loadExecutions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create execution: $e'),
            backgroundColor: KColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchOrgUsers(Dio dio) async {
    try {
      final resp = await dio.get<Map<String, dynamic>>(ApiConfig.orgUsers);
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

  Future<void> _startExecution(String id) async {
    try {
      await ref.read(fieldSalesRepositoryProvider).startExecution(id);
      _loadExecutions();
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
      _loadExecutions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete route: $e')),
        );
      }
    }
  }

  Color _statusAccent(String status) {
    switch (status.toUpperCase()) {
      case 'IN_PROGRESS':
        return KColors.warning;
      case 'COMPLETED':
        return KColors.success;
      case 'CANCELLED':
        return KColors.error;
      case 'PLANNED':
      default:
        return KColors.primary;
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
                    ? const KEmptyState(
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
                            final notes = exec['notes']?.toString();
                            final isOverridden = notes != null &&
                                notes.contains('[ADMIN');
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
                              statusAccent: _statusAccent(status),
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
                                      if (isOverridden) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: KColors.warning
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'OVERRIDDEN',
                                            style: KTypography.mono(
                                                fontSize: 10, color: KColors.warning, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        KSpacing.hGapSm,
                                      ],
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
                                  if (notes != null && notes.isNotEmpty) ...[
                                    KSpacing.vGapXs,
                                    Text(
                                      notes,
                                      style: KTypography.bodySmall.copyWith(
                                        color: isOverridden
                                            ? KColors.warning
                                            : KColors.textSecondary,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                  KSpacing.vGapSm,
                                  Row(
                                    children: [
                                      _MetricChip(
                                        icon: Icons.storefront_outlined,
                                        label: '$completedVisits/$totalVisits visits',
                                      ),
                                      KSpacing.hGapMd,
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.receipt_long_outlined,
                                              size: 13,
                                              color: KColors.textSecondary),
                                          const SizedBox(width: 4),
                                          KMoney(ordersValue),
                                        ],
                                      ),
                                      KSpacing.hGapMd,
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.payments_outlined,
                                              size: 13,
                                              color: KColors.textSecondary),
                                          const SizedBox(width: 4),
                                          KMoney(collections),
                                        ],
                                      ),
                                    ],
                                  ),
                                  KSpacing.vGapSm,
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (status == 'PLANNED')
                                        KButton.primary(
                                          label: 'Start Route',
                                          icon: Icons.play_arrow_outlined,
                                          size: KButtonSize.small,
                                          onPressed: () =>
                                              _startExecution(id),
                                        ),
                                      if (status == 'IN_PROGRESS')
                                        KButton.outlined(
                                          label: 'Complete',
                                          icon: Icons.check,
                                          size: KButtonSize.small,
                                          onPressed: () =>
                                              _completeExecution(id),
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
        backgroundColor: KColors.primary,
        foregroundColor: Colors.white,
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Execution'),
        tooltip: 'New Execution (N)',
      ),
    );
  }
}

class _CreateExecutionDialog extends StatefulWidget {
  final DateTime initialDate;
  final List<Map<String, dynamic>> routes;
  final List<Map<String, dynamic>> vans;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> assignments;
  final bool isAdmin;
  final String? currentUserId;

  const _CreateExecutionDialog({
    required this.initialDate,
    required this.routes,
    required this.vans,
    required this.users,
    required this.assignments,
    required this.isAdmin,
    this.currentUserId,
  });

  @override
  State<_CreateExecutionDialog> createState() => _CreateExecutionDialogState();
}

class _CreateExecutionDialogState extends State<_CreateExecutionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _overrideReasonController = TextEditingController();
  String? _selectedRouteId;
  String? _selectedSalespersonId;
  String? _selectedVanId;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    if (!widget.isAdmin && widget.currentUserId != null) {
      _selectedSalespersonId = widget.currentUserId;
      _onSalespersonChanged(widget.currentUserId);
    }
  }

  @override
  void dispose() {
    _overrideReasonController.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<Map<String, dynamic>> _getActiveAssignmentsFor(String spId, DateTime d) {
    final dStr = _fmtDate(d);
    return widget.assignments.where((a) {
      if (a['salespersonId']?.toString() != spId) return false;
      if (a['isActive'] == false) return false;
      final from = a['effectiveFrom']?.toString();
      if (from != null && from.compareTo(dStr) > 0) return false;
      final to = a['effectiveTo']?.toString();
      if (to != null && to.compareTo(dStr) < 0) return false;
      return true;
    }).toList();
  }

  void _onSalespersonChanged(String? spId) {
    setState(() {
      _selectedSalespersonId = spId;
      if (spId != null) {
        final active = _getActiveAssignmentsFor(spId, _date);
        if (active.isNotEmpty) {
          final first = active.first;
          _selectedRouteId = first['routeId']?.toString();
          _selectedVanId = first['vanId']?.toString();
        }
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        if (_selectedSalespersonId != null) {
          _onSalespersonChanged(_selectedSalespersonId);
        }
      });
    }
  }

  bool _isOverrideNeeded() {
    if (!widget.isAdmin) return false;
    if (_selectedSalespersonId == null || _selectedRouteId == null) return false;

    final active = _getActiveAssignmentsFor(_selectedSalespersonId!, _date);
    final routeMatch = active.where((a) => a['routeId']?.toString() == _selectedRouteId).toList();

    // Condition 1: No active assignment for this route on this date
    if (routeMatch.isEmpty) return true;

    // Condition 2: Assigned van differs from selected van
    final assignedVanId = routeMatch.first['vanId']?.toString();
    if (assignedVanId != null && _selectedVanId != null && _selectedVanId != assignedVanId) {
      return true;
    }

    return false;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRouteId == null || _selectedSalespersonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Route and Salesperson')),
      );
      return;
    }

    final overrideNeeded = _isOverrideNeeded();
    if (overrideNeeded && _overrideReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin override reason is required to start an exceptional execution'),
          backgroundColor: KColors.error,
        ),
      );
      return;
    }

    Navigator.of(context).pop({
      'routeId': _selectedRouteId,
      'salespersonId': _selectedSalespersonId,
      if (_selectedVanId != null) 'vanId': _selectedVanId,
      'executionDate': _fmtDate(_date),
      if (overrideNeeded) 'overrideReason': _overrideReasonController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeForSp = _selectedSalespersonId != null
        ? _getActiveAssignmentsFor(_selectedSalespersonId!, _date)
        : <Map<String, dynamic>>[];
    final assignedRouteIds =
        activeForSp.map((a) => a['routeId']?.toString()).whereType<String>().toSet();

    // If operator/salesperson, only show assigned routes
    final availableRoutes = widget.isAdmin
        ? widget.routes
        : widget.routes.where((r) => assignedRouteIds.contains(r['id']?.toString())).toList();

    final overrideNeeded = _isOverrideNeeded();

    return AlertDialog(
      title: const Text('Create Route Execution'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Execution Date
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Execution Date *',
                      border: OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(_fmtDate(_date)),
                  ),
                ),
                KSpacing.vGapSm,

                // Salesperson Dropdown (editable only by Admin)
                if (widget.isAdmin)
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
                      final name = (u['fullName'] ??
                              u['displayName'] ??
                              u['name'] ??
                              u['email'] ??
                              id)
                          .toString();
                      return DropdownMenuItem(
                        value: id,
                        child: Text(name, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: _onSalespersonChanged,
                  )
                else
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Salesperson',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: Text(
                      widget.users.isNotEmpty
                          ? (widget.users.first['fullName'] ?? 'Me').toString()
                          : 'Logged-in Salesperson',
                      style: KTypography.bodyMedium,
                    ),
                  ),
                KSpacing.vGapSm,

                // Unassigned Warning for Admin / Operator
                if (_selectedSalespersonId != null && activeForSp.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: KColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                      border: Border.all(
                          color: KColors.warning.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 18, color: KColors.warning),
                        KSpacing.hGapSm,
                        Expanded(
                          child: Text(
                            widget.isAdmin
                                ? 'No active assignment for this salesperson on ${_fmtDate(_date)}. An Admin Override reason will be required.'
                                : 'You have no active route assignments on ${_fmtDate(_date)}. Please contact an administrator.',
                            style: KTypography.bodySmall
                                .copyWith(color: KColors.warning),
                          ),
                        ),
                      ],
                    ),
                  ),
                  KSpacing.vGapSm,
                ],

                // Route Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedRouteId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Route *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) => v == null ? 'Required' : null,
                  items: availableRoutes.map((r) {
                    final id = r['id']?.toString() ?? '';
                    final name = r['name']?.toString() ?? 'Unnamed';
                    final code = r['code']?.toString();
                    final isAssigned = assignedRouteIds.contains(id);
                    final label = code != null ? '$name ($code)' : name;
                    return DropdownMenuItem(
                      value: id,
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(label,
                                  overflow: TextOverflow.ellipsis)),
                          if (isAssigned) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: KColors.success
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ASSIGNED',
                                style: KTypography.mono(
                                    fontSize: 10, color: KColors.success, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedRouteId = v),
                ),
                KSpacing.vGapSm,

                // Van Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedVanId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Van (Optional)',
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

                // Admin Override Reason Field (appears when override condition is met)
                if (overrideNeeded) ...[
                  KSpacing.vGapSm,
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: KColors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                      border: Border.all(
                          color: KColors.warning.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.admin_panel_settings_outlined,
                                size: 16, color: KColors.warning),
                            KSpacing.hGapXs,
                            Text(
                              'Admin Override Required',
                              style: KTypography.labelSmall.copyWith(
                                color: KColors.warning,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        KSpacing.vGapXs,
                        Text(
                          'Starting an unassigned route or overriding the assigned van requires an auditable reason.',
                          style: KTypography.bodySmall
                              .copyWith(color: KColors.textSecondary),
                        ),
                        KSpacing.vGapSm,
                        TextFormField(
                          controller: _overrideReasonController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Override Reason *',
                            hintText: 'e.g. Relieving absent driver, urgent order fulfillment',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) {
                            if (overrideNeeded &&
                                (v == null || v.trim().isEmpty)) {
                              return 'Override reason is required';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
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
          label: overrideNeeded ? 'Create with Override' : 'Create Execution',
        ),
      ],
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
