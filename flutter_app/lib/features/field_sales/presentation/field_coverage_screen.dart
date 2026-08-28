import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../data/field_sales_repository.dart';

/// Manager coverage analytics: team roll-up, tour-plan deviation, and
/// customer visit-frequency compliance. Works for all verticals.
class FieldCoverageScreen extends ConsumerStatefulWidget {
  const FieldCoverageScreen({super.key});

  @override
  ConsumerState<FieldCoverageScreen> createState() =>
      _FieldCoverageScreenState();
}

class _FieldCoverageScreenState extends ConsumerState<FieldCoverageScreen> {
  List<Map<String, dynamic>> _users = [];
  String? _selectedUserId;
  late DateTime _month;

  List<Map<String, dynamic>> _team = [];
  Map<String, dynamic>? _deviation;
  Map<String, dynamic>? _frequency;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    _loadAll();
  }

  String get _monthStr =>
      '${_month.year}-${_month.month.toString().padLeft(2, '0')}-01';

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(apiClientProvider).dio;
      final repo = ref.read(fieldSalesRepositoryProvider);

      if (_users.isEmpty) {
        final usersResp =
            await dio.get<Map<String, dynamic>>(ApiConfig.orgUsers);
        final usersData = (usersResp.data?['data'] as List?) ?? [];
        _users = usersData
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }

      final monthEnd = DateTime(_month.year, _month.month + 1, 0);
      final from = _monthStr;
      final to =
          '${monthEnd.year}-${monthEnd.month.toString().padLeft(2, '0')}-${monthEnd.day.toString().padLeft(2, '0')}';

      final futures = <Future>[
        repo.teamDashboard(from, to),
        repo.frequencyCompliance(_monthStr, salespersonId: _selectedUserId),
        if (_selectedUserId != null)
          repo.deviationReport(_monthStr, _selectedUserId!),
      ];
      final results = await Future.wait(futures);

      if (mounted) {
        setState(() {
          _team = results[0] as List<Map<String, dynamic>>;
          _frequency = results[1] as Map<String, dynamic>;
          _deviation = _selectedUserId != null
              ? results[2] as Map<String, dynamic>
              : null;
        });
      }
    } on DioException catch (e) {
      _toast('Failed to load coverage: ${e.message}', isError: true);
    } catch (e) {
      _toast('Failed to load coverage: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: 'Pick any day in the month',
    );
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month, 1));
      _loadAll();
    }
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? KColors.error : KColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Field Coverage & Analytics'),
          actions: [
            TextButton.icon(
              onPressed: _pickMonth,
              icon: const Icon(Icons.calendar_month, color: KColors.primary),
              label: Text(
                '${_month.month.toString().padLeft(2, '0')}/${_month.year}',
                style: KTypography.mono(fontWeight: FontWeight.w600, color: KColors.primary),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _loadAll,
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Team Overview'),
            Tab(text: 'Tour Deviation'),
            Tab(text: 'Visit Frequency'),
          ]),
        ),
        body: _loading
            ? const Center(child: KLoading())
            : TabBarView(children: [
                _teamTab(),
                _deviationTab(),
                _frequencyTab(),
              ]),
      ),
    );
  }

  Widget _teamTab() {
    if (_team.isEmpty) {
      return const KEmptyState(
        icon: Icons.groups_outlined,
        title: 'No route execution data found',
        subtitle: 'No field visits or route executions recorded for this selected month.',
      );
    }
    return ListView.separated(
      padding: KSpacing.pagePadding,
      itemCount: _team.length,
      separatorBuilder: (_, __) => KSpacing.vGapSm,
      itemBuilder: (context, index) {
        final r = _team[index];
        final name = (r['salespersonName']?.toString().trim().isEmpty ?? true)
            ? 'Salesperson'
            : r['salespersonName'].toString();
        final routeDays = r['routeDays'] ?? 0;
        final visitsCompleted = r['visitsCompleted'] ?? 0;
        final visitsPlanned = r['visitsPlanned'] ?? 0;
        final completionPct = r['completionPct'] ?? 0;
        final distanceKm = r['distanceKm'] ?? 0;
        final dcrsSubmitted = r['dcrsSubmitted'] ?? 0;
        final ordersValue = (r['ordersValue'] as num?)?.toDouble() ?? 0;
        final collections = (r['collections'] as num?)?.toDouble() ?? 0;

        return KCard(
          onTap: () {
            setState(() => _selectedUserId = r['salespersonId'].toString());
            _loadAll();
            DefaultTabController.of(context).animateTo(1);
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: KColors.primarySoft,
                child: const Icon(Icons.person, color: KColors.primary, size: 20),
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
                            name,
                            style: KTypography.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        KSpacing.hGapSm,
                        KStatusChip(
                          status: completionPct >= 80 ? 'APPROVED' : 'PENDING_APPROVAL',
                          label: '$completionPct% coverage',
                        ),
                      ],
                    ),
                    KSpacing.vGapXs,
                    Text(
                      'Days: $routeDays • Visits: $visitsCompleted / $visitsPlanned'
                      ' • $distanceKm km • DCRs: $dcrsSubmitted',
                      style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                    ),
                  ],
                ),
              ),
              KSpacing.hGapMd,
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  KMoney(
                    ordersValue,
                    size: KMoneySize.small,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  KSpacing.vGapXxs,
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Coll: ', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                      KMoney(
                        collections,
                        size: KMoneySize.small,
                      ),
                    ],
                  ),
                ],
              ),
              const Icon(Icons.chevron_right, color: KColors.textHint),
            ],
          ),
        );
      },
    );
  }

  Widget _deviationTab() {
    return Column(
      children: [
        Padding(
          padding: KSpacing.pagePadding,
          child: DropdownButtonFormField<String>(
            initialValue: _selectedUserId,
            decoration: const InputDecoration(
              labelText: 'Select Field Salesperson',
              border: OutlineInputBorder(),
            ),
            items: _users
                .map((u) => DropdownMenuItem(
                      value: (u['userId'] ?? u['id'])?.toString(),
                      child: Text('${u['fullName'] ?? u['displayName'] ?? u['email'] ?? ''}'),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() => _selectedUserId = v);
              _loadAll();
            },
          ),
        ),
        if (_deviation == null)
          const Expanded(
            child: KEmptyState(
              icon: Icons.alt_route_outlined,
              title: 'Select a salesperson to view tour deviation',
              subtitle: 'Compare monthly approved tour plans with daily check-ins and GPS routes.',
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                KStatusChip(
                  status: _deviation!['planStatus']?.toString() ?? 'DRAFT',
                  label: 'Plan: ${_deviation!['planStatus'] ?? 'None'}',
                ),
                KSpacing.hGapSm,
                KStatusChip(
                  status: 'APPROVED',
                  label: 'As Planned: ${_deviation!['daysAsPlanned'] ?? 0} days',
                ),
                KSpacing.hGapSm,
                KStatusChip(
                  status: 'OVERDUE',
                  label: 'Deviated: ${_deviation!['daysDeviated'] ?? 0} days',
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: KSpacing.pagePadding,
              itemCount: ((_deviation!['days'] as List?) ?? []).whereType<Map>().length,
              separatorBuilder: (_, __) => KSpacing.vGapSm,
              itemBuilder: (context, index) {
                final daysList = ((_deviation!['days'] as List?) ?? []).whereType<Map>().toList();
                final d = daysList[index];
                final status = d['status']?.toString() ?? '';
                final worked = d['worked'] == true;
                final visits = d['visitsCompleted'] ?? 0;

                return KCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: status == 'AS_PLANNED'
                            ? KColors.success.withValues(alpha: 0.12)
                            : KColors.warning.withValues(alpha: 0.12),
                        child: Icon(
                          status == 'AS_PLANNED' ? Icons.check : Icons.alt_route,
                          size: 18,
                          color: status == 'AS_PLANNED' ? KColors.success : KColors.warning,
                        ),
                      ),
                      KSpacing.hGapMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${d['date']} — ${d['plannedActivity'] ?? 'Unplanned'}'
                              '${(d['plannedArea'] ?? '').toString().isNotEmpty ? ' @ ${d['plannedArea']}' : ''}',
                              style: KTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                            ),
                            KSpacing.vGapXxs,
                            Text(
                              worked ? 'Worked ($visits visits logged)' : 'Did not work field route',
                              style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      KStatusChip(
                        status: status,
                        label: status.replaceAll('_', ' '),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _frequencyTab() {
    final f = _frequency;
    if (f == null) return const Center(child: KLoading());
    final contacts =
        ((f['contacts'] as List?) ?? []).whereType<Map>().toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              KStatusChip(
                status: 'INFO',
                label: 'Targets: ${f['totalTargets'] ?? 0}',
              ),
              KSpacing.hGapSm,
              KStatusChip(
                status: 'APPROVED',
                label: 'Compliant: ${f['compliant'] ?? 0} (${f['compliancePct'] ?? 0}%)',
              ),
            ],
          ),
        ),
        Expanded(
          child: contacts.isEmpty
              ? const KEmptyState(
                  icon: Icons.checklist_rtl_outlined,
                  title: 'No customer frequency targets set',
                  subtitle: 'Set required monthly visit frequencies in customer / doctor master profiles to track compliance.',
                )
              : ListView.separated(
                  padding: KSpacing.pagePadding,
                  itemCount: contacts.length,
                  separatorBuilder: (_, __) => KSpacing.vGapSm,
                  itemBuilder: (context, index) {
                    final c = contacts[index];
                    final ok = c['compliant'] == true;
                    final actual = c['actualVisits'] ?? 0;
                    final required = c['requiredVisits'] ?? 0;

                    return KCard(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: ok
                                ? KColors.success.withValues(alpha: 0.12)
                                : KColors.error.withValues(alpha: 0.12),
                            child: Icon(
                              ok ? Icons.check_circle : Icons.warning_amber_rounded,
                              size: 18,
                              color: ok ? KColors.success : KColors.error,
                            ),
                          ),
                          KSpacing.hGapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c['contactName']?.toString() ?? '',
                                  style: KTypography.titleMedium,
                                ),
                                KSpacing.vGapXxs,
                                Text(
                                  [
                                    c['category'],
                                    c['mrClass'] != null ? 'Class ${c['mrClass']}' : null,
                                  ].where((x) => x != null).join(' • '),
                                  style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$actual / $required visits',
                            style: KTypography.mono(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: ok ? KColors.success : KColors.error,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
