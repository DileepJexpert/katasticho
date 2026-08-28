import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_error_view.dart';
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_status_chip.dart';

class EmployeeListScreen extends ConsumerStatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  ConsumerState<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends ConsumerState<EmployeeListScreen> {
  String? _status;
  String _search = '';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _employees = [];

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(ApiConfig.payrollEmployees);
      final data = response.data['data'] ?? response.data;
      final content = data is Map ? (data['content'] as List?) ?? [] : data;
      _employees = (content as List)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } on DioException catch (e) {
      _error = ApiErrorParser.message(e);
    } catch (e) {
      _error = 'Failed to load employees';
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    return _employees.where((emp) {
      final status = emp['employmentStatus']?.toString().toUpperCase();
      if (_status != null && status != _status) return false;
      if (_search.isEmpty) return true;
      final haystack = [
        emp['fullName'],
        emp['employeeCode'],
        emp['designation'],
        emp['department'],
        emp['employmentStatus'],
      ].whereType<Object>().join(' ').toLowerCase();
      return haystack.contains(_search);
    }).toList();
  }

  void _openAtIndex(int index) {
    final filtered = _filteredEmployees;
    if (index < 0 || index >= filtered.length) return;
    final id = filtered[index]['id']?.toString();
    if (id != null) context.push('/payroll/employees/$id');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return KKeyboardListWrapper(
      itemCount: () => _filteredEmployees.length,
      onNew: () async {
        await context.push('/payroll/employees/create');
        _fetchEmployees();
      },
      onRefresh: _fetchEmployees,
      onOpen: _openAtIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Staff & Employee Directory'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _fetchEmployees,
            ),
          ],
        ),
        body: _loading
            ? const KLoading(message: 'Loading employee records...')
            : _error != null
                ? Padding(
                    padding: KSpacing.pagePadding,
                    child: KErrorView(message: _error!, onRetry: _fetchEmployees),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchEmployees,
                    child: ListView(
                      padding: KSpacing.pagePadding,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Payroll Employee Roster',
                                    style: KTypography.h2.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Manage workforce profiles, designations, salary structures, and statutory tax details.',
                                    style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            KButton.primary(
                              label: 'Add Employee',
                              icon: Icons.person_add_rounded,
                              onPressed: () async {
                                await context.push('/payroll/employees/create');
                                _fetchEmployees();
                              },
                            ),
                          ],
                        ),
                        KSpacing.vGapMd,
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _FilterChip(
                                label: 'All (${_employees.length})',
                                selected: _status == null,
                                onSelected: () => setState(() => _status = null),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Active',
                                selected: _status == 'ACTIVE',
                                onSelected: () => setState(() => _status = 'ACTIVE'),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Inactive',
                                selected: _status == 'INACTIVE',
                                onSelected: () => setState(() => _status = 'INACTIVE'),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Terminated',
                                selected: _status == 'TERMINATED',
                                onSelected: () => setState(() => _status = 'TERMINATED'),
                              ),
                            ],
                          ),
                        ),
                        KSpacing.vGapMd,
                        TextFormField(
                          decoration: InputDecoration(
                            hintText: 'Search by employee name, code, designation, or department...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(KSpacing.radiusMd)),
                          ),
                          onChanged: (val) => setState(() => _search = val.trim().toLowerCase()),
                        ),
                        KSpacing.vGapMd,
                        if (_filteredEmployees.isEmpty)
                          KEmptyState(
                            icon: Icons.people_outline_rounded,
                            title: _employees.isEmpty ? 'No employees found' : 'No matching employees',
                            subtitle: _employees.isEmpty
                                ? 'Add your first employee to start managing monthly payroll and payslips.'
                                : 'Try clearing your search query or switching status filters.',
                            actionLabel: _employees.isEmpty ? 'Add Employee' : 'Clear Filters',
                            onAction: _employees.isEmpty
                                ? () async {
                                    await context.push('/payroll/employees/create');
                                    _fetchEmployees();
                                  }
                                : () => setState(() {
                                      _status = null;
                                      _search = '';
                                    }),
                          )
                        else
                          ..._filteredEmployees.map((emp) {
                            return _EmployeeCard(
                              employee: emp,
                              onTap: () async {
                                final id = emp['id']?.toString();
                                if (id != null) {
                                  await context.push('/payroll/employees/$id');
                                  _fetchEmployees();
                                }
                              },
                            );
                          }),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      labelStyle: KTypography.labelSmall.copyWith(
        color: selected ? cs.onPrimaryContainer : cs.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      selectedColor: cs.primaryContainer,
      showCheckmark: false,
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final Map<String, dynamic> employee;
  final VoidCallback onTap;

  const _EmployeeCard({required this.employee, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fullName = employee['fullName']?.toString() ?? '--';
    final employeeCode = employee['employeeCode']?.toString();
    final designation = employee['designation']?.toString();
    final department = employee['department']?.toString();
    final status = (employee['employmentStatus']?.toString() ?? 'ACTIVE').toUpperCase();

    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      padding: const EdgeInsets.all(KSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(KSpacing.radiusMd),
        onTap: onTap,
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: cs.primary.withValues(alpha: 0.12),
              child: Text(
                _initials(fullName),
                style: KTypography.titleSmall.copyWith(
                  color: cs.primary,
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
                      Expanded(
                        child: Text(
                          fullName,
                          style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      KSpacing.hGapSm,
                      KStatusChip(status: status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (employeeCode != null && employeeCode.isNotEmpty) ...[
                        Text(
                          employeeCode,
                          style: KTypography.mono(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                      if (employeeCode != null && designation != null)
                        Text(
                          '  •  ',
                          style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                        ),
                      if (designation != null)
                        Expanded(
                          child: Text(
                            designation,
                            style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  if (department != null && department.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.business_outlined, size: 13, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          department,
                          style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            KSpacing.hGapSm,
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }
}
