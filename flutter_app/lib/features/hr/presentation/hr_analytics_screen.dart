import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_loading.dart';

/// HR Analytics — Core HR module.
class HrAnalyticsScreen extends ConsumerStatefulWidget {
  const HrAnalyticsScreen({super.key});

  @override
  ConsumerState<HrAnalyticsScreen> createState() => _HrAnalyticsScreenState();
}

class _HrAnalyticsScreenState extends ConsumerState<HrAnalyticsScreen> {
  bool _loading = true;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res =
          await ref.read(apiClientProvider).get(ApiConfig.hrAnalyticsDashboard);
      if (!mounted) return;
      setState(() =>
          _data = (res.data['data'] as Map?)?.cast<String, dynamic>() ?? {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load analytics: ${ApiErrorParser.message(e)}'),
            backgroundColor: KColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final byDept = (_data['byDepartment'] as Map?)?.cast<String, dynamic>() ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('HR Analytics & Workforce Pulse'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: KLoading(message: 'Loading HR workforce analytics...'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: KSpacing.pagePadding,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Organization Headcount & Status Pulse',
                        style: KTypography.h2.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Real-time workforce snapshot, daily attendance, pending compliance requests, and expiring KYC records.',
                        style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  KSpacing.vGapLg,
                  Wrap(
                    spacing: KSpacing.sm,
                    runSpacing: KSpacing.sm,
                    children: [
                      _metric('Total Headcount', _data['headcount'], Icons.groups_rounded, KColors.primary),
                      _metric('On Leave Today', _data['onLeaveToday'], Icons.beach_access_rounded, KColors.teal),
                      _metric('Pending Leaves', _data['pendingLeaves'], Icons.pending_actions_rounded, KColors.warning),
                      _metric('Pending Timesheets', _data['pendingTimesheets'], Icons.timer_outlined, KColors.info),
                      _metric('Pending Regs', _data['pendingRegularizations'], Icons.edit_calendar_rounded, Colors.brown),
                      _metric('Open HR Tickets', _data['openTickets'], Icons.support_agent_rounded, Colors.purple),
                      _metric('Docs Expiring (30d)', _data['documentsExpiringIn30Days'], Icons.event_busy_rounded, KColors.error),
                    ],
                  ),
                  KSpacing.vGapLg,
                  KCard(
                    title: 'Headcount by Department',
                    subtitle: 'Distribution of active employees across organizational units.',
                    child: byDept.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No departmental headcount records found.',
                              style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                            ),
                          )
                        : Column(
                            children: [
                              for (final e in byDept.entries) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          e.key,
                                          style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: cs.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                                        ),
                                        child: Text(
                                          '${e.value} staff',
                                          style: KTypography.mono(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: cs.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _metric(String label, Object? value, IconData icon, Color color) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: 175,
      child: KCard(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(KSpacing.radiusSm),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            KSpacing.vGapSm,
            Text(
              '${value ?? 0}',
              style: KTypography.mono(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            KSpacing.vGapXs,
            Text(
              label,
              style: KTypography.caption.copyWith(color: cs.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
