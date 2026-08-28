import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';
import '../data/field_sales_repository.dart';

/// Manager inbox for field submissions: monthly tour plans and daily reports
/// awaiting approval. Pharma organisations see the traditional MR wording.
class MrApprovalsScreen extends ConsumerStatefulWidget {
  const MrApprovalsScreen({super.key});

  @override
  ConsumerState<MrApprovalsScreen> createState() => _MrApprovalsScreenState();
}

class _MrApprovalsScreenState extends ConsumerState<MrApprovalsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tourPlans = [];
  List<Map<String, dynamic>> _dcrs = [];

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
        repo.pendingTourPlans(),
        repo.pendingDcrs(),
      ]);
      if (mounted) {
        setState(() {
          _tourPlans = results[0];
          _dcrs = results[1];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load approvals: $e'),
            backgroundColor: KColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _decide({
    required bool isTourPlan,
    required String id,
    required bool approve,
  }) async {
    String? reason;
    if (!approve) {
      final ctl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reject Submission'),
          content: SizedBox(
            width: 360,
            child: KTextField(
              controller: ctl,
              label: 'Rejection Reason *',
              hint: 'e.g. Inadequate doctor coverage / incomplete entries',
              maxLines: 2,
            ),
          ),
          actions: [
            KButton.outlined(
              size: KButtonSize.small,
              onPressed: () => Navigator.pop(ctx, false),
              label: 'Cancel',
            ),
            KSpacing.hGapSm,
            KButton.danger(
              size: KButtonSize.small,
              label: 'Confirm Reject',
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );
      if (ok != true) return;
      reason = ctl.text.trim();
    }

    try {
      final repo = ref.read(fieldSalesRepositoryProvider);
      if (isTourPlan) {
        approve
            ? await repo.approveTourPlan(id)
            : await repo.rejectTourPlan(id, reason ?? '');
      } else {
        approve
            ? await repo.approveDcr(id)
            : await repo.rejectDcr(id, reason ?? '');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Approved successfully' : 'Submission rejected'),
            backgroundColor: approve ? KColors.success : KColors.warning,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action failed: $e'),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showTourPlanEntries(Map<String, dynamic> plan) async {
    try {
      final detail = await ref
          .read(fieldSalesRepositoryProvider)
          .getTourPlan(plan['id'].toString());
      final entries = (detail['entries'] as List?) ?? [];
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: ListView(
            padding: KSpacing.pagePadding,
            shrinkWrap: true,
            children: [
              Text(
                'Tour Plan for ${plan['planMonth'] ?? ''}',
                style: KTypography.titleLarge,
              ),
              KSpacing.vGapMd,
              if (entries.isEmpty)
                const KEmptyState(
                  icon: Icons.calendar_today_outlined,
                  title: 'No plan entries found',
                  subtitle: 'No individual daily stops recorded for this tour plan.',
                )
              else
                ...entries.map((e) => KCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.event, color: KColors.primary, size: 20),
                          KSpacing.hGapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${e['planDate']} — ${e['activityType']}',
                                  style: KTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                                ),
                                KSpacing.vGapXxs,
                                Text(
                                  [e['area'], e['notes']]
                                      .where((x) => x != null && x.toString().trim().isNotEmpty)
                                      .join(' • '),
                                  style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load plan: $e'),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final industry = (auth.industryCode ?? auth.industry ?? '').toUpperCase();
    final isPharma = industry == 'PHARMACY' || industry.contains('PHARMA');
    final screenTitle = isPharma ? 'MR Approvals' : 'Field Approvals';
    final dailyReportLabel = isPharma ? 'DCRs' : 'Daily Reports';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(screenTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _loadData,
            ),
          ],
          bottom: TabBar(tabs: [
            Tab(text: 'Tour Plans (${_tourPlans.length})'),
            Tab(text: '$dailyReportLabel (${_dcrs.length})'),
          ]),
        ),
        body: _isLoading
            ? const Center(child: KLoading())
            : TabBarView(children: [
                _buildList(
                  items: _tourPlans,
                  emptyText: 'No tour plans awaiting approval',
                  builder: (plan) {
                    final spName = plan['salespersonName']?.toString() ?? 'Salesperson';
                    final submittedDate = plan['submittedAt']?.toString().split('T')[0] ?? '--';
                    final month = plan['planMonth']?.toString() ?? '--';

                    return KCard(
                      onTap: () => _showTourPlanEntries(plan),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: KColors.primarySoft,
                            child: const Icon(Icons.calendar_month_outlined, color: KColors.primary, size: 20),
                          ),
                          KSpacing.hGapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      spName,
                                      style: KTypography.titleMedium,
                                    ),
                                    KSpacing.hGapSm,
                                    const KStatusChip(
                                      status: 'PENDING_APPROVAL',
                                      label: 'Pending Approval',
                                    ),
                                  ],
                                ),
                                KSpacing.vGapXxs,
                                Row(
                                  children: [
                                    Text('Month: ', style: KTypography.bodySmall),
                                    Text(month, style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600)),
                                    Text('  •  Submitted: ', style: KTypography.bodySmall),
                                    Text(submittedDate, style: KTypography.mono(fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          _decisionButtons(isTourPlan: true, id: plan['id'].toString()),
                        ],
                      ),
                    );
                  },
                ),
                _buildList(
                  items: _dcrs,
                  emptyText: 'No daily call reports awaiting approval',
                  builder: (dcr) {
                    final reportDate = dcr['reportDate']?.toString() ?? '--';
                    final workType = dcr['workType']?.toString() ?? 'Field Work';
                    final totalVisits = (dcr['totalVisits'] as num?)?.toInt() ?? 0;
                    final drVisits = (dcr['doctorsVisited'] as num?)?.toInt() ?? 0;
                    final chemistVisits = (dcr['chemistsVisited'] as num?)?.toInt() ?? 0;
                    final pob = (dcr['totalPob'] as num?)?.toDouble() ?? 0;
                    final samples = (dcr['samplesGiven'] as num?)?.toInt() ?? 0;

                    return KCard(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: KColors.primarySoft,
                            child: const Icon(Icons.assignment_outlined, color: KColors.primary, size: 20),
                          ),
                          KSpacing.hGapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '$reportDate — $workType',
                                      style: KTypography.titleMedium,
                                    ),
                                    KSpacing.hGapSm,
                                    const KStatusChip(
                                      status: 'SUBMITTED',
                                      label: 'Pending Review',
                                    ),
                                  ],
                                ),
                                KSpacing.vGapXxs,
                                if (isPharma)
                                  Text(
                                    'Visits: $totalVisits (Doctors: $drVisits, Chemists: $chemistVisits) • Samples: $samples',
                                    style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                                  )
                                else
                                  Text(
                                    'Visits: $totalVisits • Samples/Items: $samples',
                                    style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                                  ),
                                if (pob > 0) ...[
                                  KSpacing.vGapXxs,
                                  Row(
                                    children: [
                                      Text('POB / Booked Orders: ', style: KTypography.labelSmall),
                                      KMoney(pob, size: KMoneySize.small),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          _decisionButtons(isTourPlan: false, id: dcr['id'].toString()),
                        ],
                      ),
                    );
                  },
                ),
              ]),
      ),
    );
  }

  Widget _buildList({
    required List<Map<String, dynamic>> items,
    required String emptyText,
    required Widget Function(Map<String, dynamic>) builder,
  }) {
    if (items.isEmpty) {
      return KEmptyState(
        icon: Icons.checklist_outlined,
        title: 'Inbox is clear',
        subtitle: emptyText,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: KSpacing.pagePadding,
        itemCount: items.length,
        separatorBuilder: (_, __) => KSpacing.vGapSm,
        itemBuilder: (context, i) => builder(items[i]),
      ),
    );
  }

  Widget _decisionButtons({required bool isTourPlan, required String id}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.check_circle_outline, color: KColors.success),
          tooltip: 'Approve',
          onPressed: () => _decide(isTourPlan: isTourPlan, id: id, approve: true),
        ),
        IconButton(
          icon: const Icon(Icons.cancel_outlined, color: KColors.error),
          tooltip: 'Reject',
          onPressed: () =>
              _decide(isTourPlan: isTourPlan, id: id, approve: false),
        ),
      ],
    );
  }
}
