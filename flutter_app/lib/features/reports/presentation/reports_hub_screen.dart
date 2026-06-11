import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';

class ReportsHubScreen extends StatelessWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final groups = _reportGroups(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView.separated(
        padding: KSpacing.pagePadding,
        itemCount: groups.length,
        separatorBuilder: (_, __) => KSpacing.vGapMd,
        itemBuilder: (context, index) => _ReportGroup(group: groups[index]),
      ),
    );
  }
}

class _ReportGroup extends StatelessWidget {
  final _ReportGroupData group;

  const _ReportGroup({required this.group});

  @override
  Widget build(BuildContext context) {
    return KCard(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.md,
        vertical: KSpacing.sm,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= KSpacing.desktopBreakpoint
              ? 3
              : constraints.maxWidth >= KSpacing.mobileBreakpoint
                  ? 2
                  : 1;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(group.title, style: KTypography.labelLarge),
              ),
              const Divider(height: 1),
              KSpacing.vGapXs,
              Wrap(
                spacing: KSpacing.sm,
                runSpacing: 4,
                children: group.reports
                    .map((report) => SizedBox(
                          width: (constraints.maxWidth -
                                  (KSpacing.sm * (columns - 1))) /
                              columns,
                          child: _ReportRow(report: report),
                        ))
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final _ReportLink report;

  const _ReportRow({required this.report});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: KSpacing.borderRadiusMd,
      onTap: report.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            Icon(report.icon, size: 18, color: report.color),
            KSpacing.hGapSm,
            Expanded(
              child: Text(
                report.title,
                style: KTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: KColors.textHint),
          ],
        ),
      ),
    );
  }
}

List<_ReportGroupData> _reportGroups(BuildContext context) => [
      _ReportGroupData(
        title: 'Financial',
        reports: [
          _ReportLink(
            icon: Icons.balance,
            title: 'Trial Balance',
            color: KColors.primary,
            onTap: () => context.push(Routes.trialBalance),
          ),
          _ReportLink(
            icon: Icons.trending_up,
            title: 'Profit & Loss',
            color: KColors.success,
            onTap: () => context.push(Routes.profitLoss),
          ),
          _ReportLink(
            icon: Icons.account_balance,
            title: 'Balance Sheet',
            color: KColors.secondary,
            onTap: () => context.push(Routes.balanceSheet),
          ),
          _ReportLink(
            icon: Icons.menu_book,
            title: 'General Ledger',
            color: KColors.info,
            onTap: () => context.push(Routes.generalLedger),
          ),
          _ReportLink(
            icon: Icons.event_note_outlined,
            title: 'Day Book',
            color: KColors.info,
            onTap: () => _openOperational(context, 'day-book', 'Day Book'),
          ),
          _ReportLink(
            icon: Icons.water_drop_outlined,
            title: 'Cash Flow',
            color: KColors.success,
            onTap: () =>
                _openOperational(context, 'cash-flow', 'Cash Flow Statement'),
          ),
          _ReportLink(
            icon: Icons.list_alt_outlined,
            title: 'Journal Register',
            color: KColors.secondary,
            onTap: () => _openOperational(
                context, 'journal-register', 'Journal Register'),
          ),
          _ReportLink(
            icon: Icons.workspaces_outlined,
            title: 'Cost Centres',
            color: KColors.warning,
            onTap: () =>
                _openOperational(context, 'cost-centres', 'Cost Centres'),
          ),
        ],
      ),
      _ReportGroupData(
        title: 'Sales & Receivables',
        reports: [
          _ReportLink(
            icon: Icons.local_shipping_outlined,
            title: 'Pending Dispatch',
            color: KColors.warning,
            onTap: () => _openOperational(
              context,
              'pending-dispatch',
              'Pending Dispatch',
              dateRange: false,
            ),
          ),
          _ReportLink(
            icon: Icons.receipt_long_outlined,
            title: 'Challan Not Invoiced',
            color: KColors.error,
            onTap: () => _openOperational(
              context,
              'challan-not-invoiced',
              'Challan Not Invoiced',
              dateRange: false,
            ),
          ),
          _ReportLink(
            icon: Icons.percent_outlined,
            title: 'Interest on Overdue',
            color: KColors.error,
            onTap: () => _openOperational(
              context,
              'overdue-interest',
              'Interest on Overdue',
              dateRange: false,
            ),
          ),
          _ReportLink(
            icon: Icons.point_of_sale_outlined,
            title: 'Daily Sales',
            color: KColors.success,
            onTap: () =>
                _openOperational(context, 'daily-sales', 'Daily Sales'),
          ),
          _ReportLink(
            icon: Icons.receipt_long_outlined,
            title: 'Sales Register',
            color: KColors.primary,
            onTap: () =>
                _openOperational(context, 'sales-register', 'Sales Register'),
          ),
          _ReportLink(
            icon: Icons.timelapse,
            title: 'AR Ageing',
            color: KColors.warning,
            onTap: () => context.push(Routes.ageingReport),
          ),
          _ReportLink(
            icon: Icons.receipt_long,
            title: 'GSTR-1',
            color: KColors.accent,
            onTap: () => context.push(Routes.gst),
          ),
        ],
      ),
      _ReportGroupData(
        title: 'Purchases & Payables',
        reports: [
          _ReportLink(
            icon: Icons.shopping_bag_outlined,
            title: 'Purchase Register',
            color: KColors.warning,
            onTap: () => _openOperational(
              context,
              'purchase-register',
              'Purchase Register',
            ),
          ),
          _ReportLink(
            icon: Icons.timelapse,
            title: 'AP Ageing',
            color: KColors.ageing61to90,
            onTap: () => context.push(Routes.apAgeingReport),
          ),
        ],
      ),
      _ReportGroupData(
        title: 'Inventory',
        reports: [
          _ReportLink(
            icon: Icons.inventory_2_outlined,
            title: 'Stock Summary',
            color: KColors.secondary,
            onTap: () => _openOperational(
              context,
              'stock-summary',
              'Stock Summary',
              dateRange: false,
            ),
          ),
          _ReportLink(
            icon: Icons.swap_vert_outlined,
            title: 'Stock Movement',
            color: KColors.accent,
            onTap: () =>
                _openOperational(context, 'stock-movement', 'Stock Movement'),
          ),
          _ReportLink(
            icon: Icons.warning_amber_outlined,
            title: 'Low Stock Alert',
            color: KColors.error,
            onTap: () => _openOperational(
              context,
              'low-stock',
              'Low Stock Alert',
              dateRange: false,
            ),
          ),
        ],
      ),
      _ReportGroupData(
        title: 'Tax & Compliance',
        reports: [
          _ReportLink(
            icon: Icons.calculate_outlined,
            title: 'GST Summary',
            color: KColors.primary,
            onTap: () =>
                _openOperational(context, 'gst-summary', 'GST Summary'),
          ),
        ],
      ),
    ];

void _openOperational(
  BuildContext context,
  String key,
  String title, {
  bool dateRange = true,
}) {
  context.push(
    '/reports/operational/$key?title=${Uri.encodeQueryComponent(title)}&dateRange=$dateRange',
  );
}

class _ReportGroupData {
  final String title;
  final List<_ReportLink> reports;

  const _ReportGroupData({
    required this.title,
    required this.reports,
  });
}

class _ReportLink {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _ReportLink({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });
}
