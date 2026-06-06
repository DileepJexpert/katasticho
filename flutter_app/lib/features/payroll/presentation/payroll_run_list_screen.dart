import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/widgets.dart';

const _statusTabs = [
  KListTab(label: 'All'),
  KListTab(label: 'Draft', value: 'DRAFT'),
  KListTab(label: 'Calculated', value: 'CALCULATED'),
  KListTab(label: 'Approved', value: 'APPROVED'),
  KListTab(label: 'Posted', value: 'POSTED'),
  KListTab(label: 'Cancelled', value: 'CANCELLED'),
];

class PayrollRunListScreen extends ConsumerStatefulWidget {
  const PayrollRunListScreen({super.key});

  @override
  ConsumerState<PayrollRunListScreen> createState() =>
      _PayrollRunListScreenState();
}

class _PayrollRunListScreenState extends ConsumerState<PayrollRunListScreen> {
  String? _status;
  String _search = '';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _runs = [];

  @override
  void initState() {
    super.initState();
    _fetchRuns();
  }

  Future<void> _fetchRuns() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(ApiConfig.payrollRuns);
      final data = response.data['data'] ?? response.data;
      final content = data is Map ? (data['content'] as List?) ?? [] : data;
      _runs = (content as List)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } on DioException catch (e) {
      final body = e.response?.data;
      _error = (body is Map ? body['message'] as String? : null) ??
          'Failed to load payroll runs';
    } catch (e) {
      _error = 'Failed to load payroll runs';
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filteredRuns {
    return _runs.where((run) {
      final status = run['status']?.toString();
      if (_status != null && status != _status) return false;
      if (_search.isEmpty) return true;
      final haystack = [
        run['runNumber'],
        run['periodStart'],
        run['periodEnd'],
        run['status'],
        run['notes'],
      ].whereType<Object>().join(' ').toLowerCase();
      return haystack.contains(_search);
    }).toList();
  }

  Future<void> _showCreateDialog() async {
    final now = DateTime.now();
    var periodStart = DateTime(now.year, now.month, 1);
    var periodEnd = DateTime(now.year, now.month + 1, 0); // last day of month

    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (ctx) => _CreatePayrollRunDialog(
        initialStart: periodStart,
        initialEnd: periodEnd,
      ),
    );

    if (result == null || !mounted) return;

    periodStart = result['periodStart']!;
    periodEnd = result['periodEnd']!;

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.post(
        ApiConfig.payrollRuns,
        data: {
          'periodStart': DateFormatter.api(periodStart),
          'periodEnd': DateFormatter.api(periodEnd),
        },
      );

      final data = response.data['data'] ?? response.data;
      final newId = data is Map ? data['id']?.toString() : null;

      await _fetchRuns();

      if (mounted && newId != null) {
        context.push('/payroll/runs/$newId');
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final body = e.response?.data;
      final message = (body is Map ? body['message'] as String? : null) ??
          'Failed to create payroll run';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create payroll run')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Payroll Runs',
            searchHint: 'Search run number, period...',
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
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Run'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const KShimmerList();

    if (_error != null) {
      return KErrorView(
        message: _error!,
        onRetry: _fetchRuns,
      );
    }

    if (_runs.isEmpty) {
      return KEmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No payroll runs yet',
        subtitle:
            'Create a payroll run to process salaries for your employees.',
        actionLabel: 'New Run',
        onAction: _showCreateDialog,
      );
    }

    final filtered = _filteredRuns;

    if (filtered.isEmpty) {
      return KEmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No matching payroll runs',
        subtitle: 'Try another status or search term.',
        actionLabel: 'Clear Filters',
        onAction: () => setState(() {
          _status = null;
          _search = '';
        }),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchRuns,
      child: ListView.separated(
        padding: KSpacing.pagePadding,
        itemCount: filtered.length,
        separatorBuilder: (_, __) => KSpacing.vGapSm,
        itemBuilder: (context, index) {
          final run = filtered[index];
          return _PayrollRunCard(
            run: run,
            onTap: () async {
              final id = run['id']?.toString();
              if (id != null) {
                await context.push('/payroll/runs/$id');
                _fetchRuns();
              }
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create dialog
// ---------------------------------------------------------------------------

class _CreatePayrollRunDialog extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;

  const _CreatePayrollRunDialog({
    required this.initialStart,
    required this.initialEnd,
  });

  @override
  State<_CreatePayrollRunDialog> createState() =>
      _CreatePayrollRunDialogState();
}

class _CreatePayrollRunDialogState extends State<_CreatePayrollRunDialog> {
  late DateTime _periodStart;
  late DateTime _periodEnd;

  @override
  void initState() {
    super.initState();
    _periodStart = widget.initialStart;
    _periodEnd = widget.initialEnd;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _periodStart : _periodEnd;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _periodStart = picked;
          // Auto-adjust end if start moves past end
          if (_periodStart.isAfter(_periodEnd)) {
            _periodEnd = DateTime(picked.year, picked.month + 1, 0);
          }
        } else {
          _periodEnd = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Payroll Run'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: const Text('Period Start'),
            subtitle: Text(DateFormatter.display(_periodStart)),
            onTap: () => _pickDate(isStart: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: const Text('Period End'),
            subtitle: Text(DateFormatter.display(_periodEnd)),
            onTap: () => _pickDate(isStart: false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_periodEnd.isBefore(_periodStart)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Period end must be after period start'),
                ),
              );
              return;
            }
            Navigator.of(context).pop({
              'periodStart': _periodStart,
              'periodEnd': _periodEnd,
            });
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Payroll run card
// ---------------------------------------------------------------------------

class _PayrollRunCard extends StatelessWidget {
  final Map<String, dynamic> run;
  final VoidCallback onTap;

  const _PayrollRunCard({required this.run, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = run['status']?.toString() ?? 'DRAFT';
    final employeeCount = (run['employeeCount'] as num?)?.toInt() ?? 0;
    final grossTotal = (run['totalGross'] as num?)?.toDouble() ?? 0;
    final netTotal = (run['totalNet'] as num?)?.toDouble() ?? 0;

    // Parse period dates
    final periodStartRaw = run['periodStart']?.toString();
    final periodEndRaw = run['periodEnd']?.toString();
    final periodLabel = _formatPeriodLabel(periodStartRaw, periodEndRaw);

    return KCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _statusAccentColor(status).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: _statusAccentColor(status),
              size: 20,
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
                        'Payroll: $periodLabel',
                        style: KTypography.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    KSpacing.hGapSm,
                    KStatusChip(status: status),
                  ],
                ),
                KSpacing.vGapXs,
                Row(
                  children: [
                    Icon(Icons.people_outline,
                        size: 12, color: KColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '$employeeCount employee${employeeCount == 1 ? '' : 's'}',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary),
                    ),
                  ],
                ),
                KSpacing.vGapXs,
                Row(
                  children: [
                    Text(
                      'Gross: ${CurrencyFormatter.formatIndian(grossTotal)}',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Net: ${CurrencyFormatter.formatIndian(netTotal)}',
                      style: KTypography.bodySmall.copyWith(
                        color: KColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: KColors.textHint),
        ],
      ),
    );
  }

  String _formatPeriodLabel(String? startRaw, String? endRaw) {
    if (startRaw == null || endRaw == null) return '--';
    try {
      final start = DateTime.parse(startRaw);
      final end = DateTime.parse(endRaw);

      // If both dates are in the same month, show "MMM yyyy" style
      if (start.year == end.year && start.month == end.month) {
        return DateFormatter.monthYear(start);
      }
      // Otherwise show full range
      return '${DateFormatter.display(start)} to ${DateFormatter.display(end)}';
    } catch (_) {
      return '$startRaw - $endRaw';
    }
  }

  Color _statusAccentColor(String status) {
    return switch (status) {
      'DRAFT' => KColors.textSecondary,
      'CALCULATED' => KColors.info,
      'APPROVED' => KColors.warning,
      'POSTED' => KColors.success,
      'CANCELLED' => KColors.error,
      _ => KColors.textSecondary,
    };
  }
}
