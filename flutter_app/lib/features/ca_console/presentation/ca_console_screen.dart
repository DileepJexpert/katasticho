import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../data/ca_console_repository.dart';

class CaConsoleScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const CaConsoleScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<CaConsoleScreen> createState() => _CaConsoleScreenState();
}

class _CaConsoleScreenState extends ConsumerState<CaConsoleScreen> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _CaDashboardTab(onOpenTab: (i) => setState(() => _tab = i)),
      const _CaCalendarTab(),
      const _CaAlertsTab(),
      const _CaReportsTab(),
    ];
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                    icon: Icon(Icons.dashboard_outlined), label: Text('Clients')),
                NavigationRailDestination(
                    icon: Icon(Icons.calendar_month_outlined), label: Text('Calendar')),
                NavigationRailDestination(
                    icon: Icon(Icons.notifications_active_outlined), label: Text('Alerts')),
                NavigationRailDestination(
                    icon: Icon(Icons.send_outlined), label: Text('Reports')),
              ],
            ),
          Expanded(child: pages[_tab]),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Clients'),
                NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'Calendar'),
                NavigationDestination(icon: Icon(Icons.notifications_active_outlined), label: 'Alerts'),
                NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
              ],
            ),
    );
  }
}

class _CaDashboardTab extends ConsumerWidget {
  final ValueChanged<int> onOpenTab;

  const _CaDashboardTab({required this.onOpenTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(caConsoleRepositoryProvider);
    return FutureBuilder<Map<String, dynamic>>(
      future: repo.getDashboard(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) return _ErrorState(error: snapshot.error);
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final clients = (data['clients'] as List? ?? const []);
        return _Page(
          title: 'CA Console',
          subtitle: 'Multi-client accounting control room',
          actions: [
            KButton(
              label: 'Generate deadlines',
              icon: Icons.auto_fix_high_outlined,
              onPressed: () async {
                await repo.generateDeadlines();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Compliance deadlines generated')));
                }
              },
            ),
          ],
          child: ListView(
            padding: KSpacing.pagePadding,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricTile(label: 'Total Clients', value: '${data['totalClients'] ?? 0}'),
                  _MetricTile(label: 'Needs Attention', value: '${data['criticalCount'] ?? 0}', color: KColors.error),
                  _MetricTile(label: 'GST Due This Week', value: '${data['gstDueThisWeekCount'] ?? 0}', color: KColors.warning),
                  _MetricTile(label: 'Unbalanced TB', value: '${data['unbalancedTrialBalanceCount'] ?? 0}'),
                ],
              ),
              KSpacing.vGapLg,
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Search clients',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                    ),
                  ),
                  KSpacing.hGapMd,
                  KButton(label: 'Calendar', icon: Icons.calendar_month, onPressed: () => onOpenTab(1)),
                  KSpacing.hGapSm,
                  KButton(label: 'Alerts', icon: Icons.notifications, onPressed: () => onOpenTab(2)),
                ],
              ),
              KSpacing.vGapMd,
              ...clients.map((raw) => _ClientCard(client: raw as Map<String, dynamic>)),
            ],
          ),
        );
      },
    );
  }
}

class _ClientCard extends ConsumerWidget {
  final Map<String, dynamic> client;

  const _ClientCard({required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = client['healthStatus']?.toString() ?? 'GREEN';
    final color = health == 'RED'
        ? KColors.error
        : health == 'AMBER'
            ? KColors.warning
            : KColors.success;
    final reasons = (client['healthReasons'] as List? ?? const []);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
              KSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(client['clientOrgName']?.toString() ?? 'Client', style: KTypography.h3)),
                        KStatusChip(status: health, label: health),
                      ],
                    ),
                    KSpacing.vGapXs,
                    Text('${client['industry'] ?? 'Business'} • ${client['engagementType'] ?? 'FULL_SERVICE'}',
                        style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                    KSpacing.vGapSm,
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        Text('${client['issueCount'] ?? 0} issues', style: KTypography.bodySmall),
                        Text(_deadlineText(client), style: KTypography.bodySmall),
                        Text('Staff: ${client['assignedStaffName'] ?? '-'}', style: KTypography.bodySmall),
                      ],
                    ),
                    if (reasons.isNotEmpty) ...[
                      KSpacing.vGapSm,
                      Text(reasons.take(2).join(' • '), style: KTypography.bodySmall.copyWith(color: color)),
                    ],
                  ],
                ),
              ),
              KSpacing.hGapMd,
              Align(
                alignment: Alignment.center,
                child: KButton(
                  label: 'Open Books',
                  icon: Icons.open_in_new_rounded,
                  onPressed: () async {
                    final linkId = client['linkId']?.toString();
                    if (linkId == null) return;
                    final result = await ref.read(caConsoleRepositoryProvider).openBooks(linkId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Delegated access ready until ${result['expiresAt'] ?? ''}')),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _deadlineText(Map<String, dynamic> c) {
    final type = c['nextDeadlineType'];
    final date = c['nextDeadlineDate'];
    if (type == null || date == null) return 'No upcoming GST deadline';
    return '$type due $date';
  }
}

class _CaCalendarTab extends ConsumerStatefulWidget {
  const _CaCalendarTab();

  @override
  ConsumerState<_CaCalendarTab> createState() => _CaCalendarTabState();
}

class _CaCalendarTabState extends ConsumerState<_CaCalendarTab> {
  bool _overdueOnly = false;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(caConsoleRepositoryProvider);
    return FutureBuilder<List<dynamic>>(
      future: repo.getDeadlines(status: _overdueOnly ? 'PENDING' : null),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) return _ErrorState(error: snapshot.error);
          return const Center(child: CircularProgressIndicator());
        }
        final today = DateTime.now();
        final rows = snapshot.data!
            .where((d) => !_overdueOnly || DateTime.parse(d['dueDate']).isBefore(DateTime(today.year, today.month, today.day)))
            .toList();
        return _Page(
          title: 'Compliance Calendar',
          subtitle: 'GST and statutory deadlines across clients',
          actions: [
            FilterChip(
              selected: _overdueOnly,
              label: const Text('Overdue'),
              onSelected: (v) => setState(() => _overdueOnly = v),
            ),
          ],
          child: ListView(
            padding: KSpacing.pagePadding,
            children: rows.map((raw) => _DeadlineTile(deadline: raw as Map<String, dynamic>)).toList(),
          ),
        );
      },
    );
  }
}

class _DeadlineTile extends ConsumerWidget {
  final Map<String, dynamic> deadline;

  const _DeadlineTile({required this.deadline});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = deadline['dueDate']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        child: Row(
          children: [
            const Icon(Icons.event_note_outlined),
            KSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deadline['clientOrgName']?.toString() ?? 'Client', style: KTypography.labelLarge),
                  Text('${deadline['deadlineType']} • ${deadline['periodLabel']} • Due $due',
                      style: KTypography.bodySmall),
                ],
              ),
            ),
            KStatusChip(status: deadline['status']?.toString() ?? 'PENDING'),
            KSpacing.hGapSm,
            KButton(
              label: 'Filed',
              size: KButtonSize.small,
              icon: Icons.check_rounded,
              onPressed: () async {
                await ref.read(caConsoleRepositoryProvider).markFiled(deadline['id'].toString());
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deadline marked filed')));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CaAlertsTab extends ConsumerStatefulWidget {
  const _CaAlertsTab();

  @override
  ConsumerState<_CaAlertsTab> createState() => _CaAlertsTabState();
}

class _CaAlertsTabState extends ConsumerState<_CaAlertsTab> {
  String? _severity;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(caConsoleRepositoryProvider);
    return FutureBuilder<List<dynamic>>(
      future: repo.getAlerts(severity: _severity),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) return _ErrorState(error: snapshot.error);
          return const Center(child: CircularProgressIndicator());
        }
        return _Page(
          title: 'AI Alert Feed',
          subtitle: 'Cross-client accounting and GST review queue',
          actions: [
            DropdownButton<String?>(
              value: _severity,
              hint: const Text('All severity'),
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(value: 'CRITICAL', child: Text('Critical')),
                DropdownMenuItem(value: 'HIGH', child: Text('High')),
                DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
              ],
              onChanged: (v) => setState(() => _severity = v),
            ),
          ],
          child: ListView(
            padding: KSpacing.pagePadding,
            children: snapshot.data!.map((raw) => _AlertTile(alert: raw as Map<String, dynamic>)).toList(),
          ),
        );
      },
    );
  }
}

class _AlertTile extends ConsumerWidget {
  final Map<String, dynamic> alert;

  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priority = alert['priority']?.toString() ?? 'MEDIUM';
    final color = priority == 'CRITICAL'
        ? KColors.error
        : priority == 'HIGH'
            ? KColors.warning
            : KColors.info;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        child: Row(
          children: [
            Container(width: 4, height: 72, color: color),
            KSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert['clientOrgName']?.toString() ?? 'Client', style: KTypography.labelSmall),
                  Text(alert['title']?.toString() ?? alert['suggestionType']?.toString() ?? 'Alert',
                      style: KTypography.labelLarge),
                  Text(alert['reasoning']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            KStatusChip(status: priority, label: priority),
            KSpacing.hGapSm,
            KButton(
              label: 'Review',
              size: KButtonSize.small,
              icon: Icons.open_in_new_rounded,
              onPressed: () {
                final entityType = alert['entityType']?.toString();
                final entityId = alert['entityId']?.toString();
                if (entityType == 'INVOICE' && entityId != null) context.push('/invoices/$entityId');
              },
            ),
            KSpacing.hGapXs,
            KButton(
              label: 'Dismiss',
              size: KButtonSize.small,
              variant: KButtonVariant.outlined,
              icon: Icons.close_rounded,
              onPressed: () async {
                await ref.read(caConsoleRepositoryProvider).dismissAlert(alert['id'].toString());
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alert dismissed')));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CaReportsTab extends ConsumerStatefulWidget {
  const _CaReportsTab();

  @override
  ConsumerState<_CaReportsTab> createState() => _CaReportsTabState();
}

class _CaReportsTabState extends ConsumerState<_CaReportsTab> {
  final Set<String> _selectedClients = {};
  final Set<String> _reports = {'PL', 'BS', 'GST_SUMMARY'};
  bool _ai = true;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(caConsoleRepositoryProvider);
    return FutureBuilder<List<dynamic>>(
      future: repo.getClients(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) return _ErrorState(error: snapshot.error);
          return const Center(child: CircularProgressIndicator());
        }
        final clients = snapshot.data!;
        return _Page(
          title: 'Report Dispatch',
          subtitle: 'Queue monthly packs for selected clients',
          actions: [
            KButton(
              label: 'Send Reports',
              icon: Icons.send_rounded,
              onPressed: _selectedClients.isEmpty
                  ? null
                  : () async {
                      final result = await repo.dispatchReports(
                        clientOrgIds: _selectedClients.toList(),
                        periodLabel: _periodLabel(),
                        reportTypes: _reports.toList(),
                        sendVia: 'EMAIL',
                        includeAiCommentary: _ai,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${result.length} dispatch jobs queued')));
                      }
                    },
            ),
          ],
          child: ListView(
            padding: KSpacing.pagePadding,
            children: [
              Wrap(
                spacing: 8,
                children: ['PL', 'BS', 'CASHFLOW', 'GST_SUMMARY', 'AR_AGING', 'AP_AGING']
                    .map((r) => FilterChip(
                          label: Text(r),
                          selected: _reports.contains(r),
                          onSelected: (v) => setState(() => v ? _reports.add(r) : _reports.remove(r)),
                        ))
                    .toList(),
              ),
              SwitchListTile(
                value: _ai,
                title: const Text('Include AI commentary'),
                onChanged: (v) => setState(() => _ai = v),
              ),
              KSpacing.vGapMd,
              ...clients.map((raw) {
                final c = raw as Map<String, dynamic>;
                final id = c['clientOrgId'].toString();
                return CheckboxListTile(
                  value: _selectedClients.contains(id),
                  title: Text(c['clientOrgName']?.toString() ?? 'Client'),
                  subtitle: Text(c['assignedStaffName']?.toString() ?? 'Unassigned'),
                  onChanged: (v) => setState(() => v == true ? _selectedClients.add(id) : _selectedClients.remove(id)),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  String _periodLabel() {
    final now = DateTime.now();
    return '${now.month.toString().padLeft(2, '0')}/${now.year}';
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _MetricTile({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: KTypography.labelSmall.copyWith(color: KColors.textSecondary)),
            const SizedBox(height: 4),
            Text(value, style: KTypography.h1.copyWith(color: color ?? KColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final Widget child;

  const _Page({
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: KTypography.h1),
                    Text(subtitle, style: KTypography.bodyMedium.copyWith(color: KColors.textSecondary)),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object? error;

  const _ErrorState({this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Could not load CA Console: $error'),
      ),
    );
  }
}
