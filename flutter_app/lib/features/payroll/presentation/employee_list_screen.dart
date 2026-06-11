import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/widgets/widgets.dart';

const _statusTabs = [
  KListTab(label: 'All'),
  KListTab(label: 'Active', value: 'ACTIVE'),
  KListTab(label: 'Inactive', value: 'INACTIVE'),
  KListTab(label: 'Terminated', value: 'TERMINATED'),
];

class EmployeeListScreen extends ConsumerStatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  ConsumerState<EmployeeListScreen> createState() =>
      _EmployeeListScreenState();
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
      final body = e.response?.data;
      _error = (body is Map ? body['message'] as String? : null) ??
          'Failed to load employees';
    } catch (e) {
      _error = 'Failed to load employees';
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    return _employees.where((emp) {
      final status = emp['employmentStatus']?.toString();
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
    final filtered = _filteredEmployees;
    return KKeyboardListWrapper(
      itemCount: filtered.length,
      onNew: () async {
        await context.push('/payroll/employees/create');
        _fetchEmployees();
      },
      onRefresh: _fetchEmployees,
      onOpen: _openAtIndex,
      child: Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Employees',
            searchHint: 'Search name, code, department...',
            tabs: _statusTabs,
            selectedTab: _status,
            onTabChanged: (value) => setState(() => _status = value),
            onSearchChanged: (value) =>
                setState(() => _search = value.trim().toLowerCase()),
          ),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/payroll/employees/create');
          _fetchEmployees();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Employee'),
        tooltip: 'Add Employee (N)',
      ),
    ));
  }

  Widget _buildBody() {
    if (_loading) return const KShimmerList();

    if (_error != null) {
      return KErrorView(
        message: _error!,
        onRetry: _fetchEmployees,
      );
    }

    if (_employees.isEmpty) {
      return KEmptyState(
        icon: Icons.people_outline,
        title: 'No employees found',
        subtitle:
            'Add your first employee to start managing payroll.',
        actionLabel: 'Add Employee',
        onAction: () async {
          await context.push('/payroll/employees/create');
          _fetchEmployees();
        },
      );
    }

    final filtered = _filteredEmployees;

    if (filtered.isEmpty) {
      return KEmptyState(
        icon: Icons.people_outline,
        title: 'No matching employees',
        subtitle: 'Try another status or search term.',
        actionLabel: 'Clear Filters',
        onAction: () => setState(() {
          _status = null;
          _search = '';
        }),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchEmployees,
      child: ListView.separated(
        padding: KSpacing.pagePadding,
        itemCount: filtered.length,
        separatorBuilder: (_, __) => KSpacing.vGapSm,
        itemBuilder: (context, index) {
          final employee = filtered[index];
          return _EmployeeCard(
            employee: employee,
            onTap: () async {
              final id = employee['id']?.toString();
              if (id != null) {
                await context.push('/payroll/employees/$id');
                _fetchEmployees();
              }
            },
          );
        },
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final Map<String, dynamic> employee;
  final VoidCallback onTap;

  const _EmployeeCard({required this.employee, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fullName = employee['fullName']?.toString() ?? '--';
    final employeeCode = employee['employeeCode']?.toString();
    final designation = employee['designation']?.toString();
    final department = employee['department']?.toString();
    final status = employee['employmentStatus']?.toString() ?? 'ACTIVE';

    final statusColor = switch (status) {
      'ACTIVE' => KColors.success,
      'INACTIVE' => KColors.warning,
      'TERMINATED' => KColors.error,
      _ => KColors.textSecondary,
    };

    final statusLabel = switch (status) {
      'ACTIVE' => 'Active',
      'INACTIVE' => 'Inactive',
      'TERMINATED' => 'Terminated',
      _ => status,
    };

    return KCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(fullName),
              style: KTypography.labelLarge.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: KTypography.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                KSpacing.vGapXs,
                Row(
                  children: [
                    if (employeeCode != null) ...[
                      Text(
                        employeeCode,
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary),
                      ),
                    ],
                    if (employeeCode != null && designation != null)
                      Text(
                        ' • ',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary),
                      ),
                    if (designation != null)
                      Expanded(
                        child: Text(
                          designation,
                          style: KTypography.bodySmall
                              .copyWith(color: KColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                if (department != null) ...[
                  KSpacing.vGapXs,
                  Row(
                    children: [
                      Icon(Icons.business_outlined,
                          size: 12, color: KColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        department,
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              statusLabel,
              style: KTypography.labelSmall.copyWith(color: statusColor),
            ),
          ),
          KSpacing.hGapSm,
          const Icon(Icons.chevron_right, color: KColors.textHint),
        ],
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
