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
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= KSpacing.desktopBreakpoint ? 3 : 2;

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: SingleChildScrollView(
        padding: KSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Financial Reports
            Text('Financial Reports', style: KTypography.h2),
            KSpacing.vGapMd,
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: KSpacing.md,
              mainAxisSpacing: KSpacing.md,
              childAspectRatio: 1.4,
              children: [
                _ReportTile(
                  icon: Icons.balance,
                  title: 'Trial Balance',
                  subtitle: 'Verify double-entry accuracy',
                  color: KColors.primary,
                  onTap: () => context.go(Routes.trialBalance),
                ),
                _ReportTile(
                  icon: Icons.trending_up,
                  title: 'Profit & Loss',
                  subtitle: 'Revenue vs expenses',
                  color: KColors.success,
                  onTap: () => context.go(Routes.profitLoss),
                ),
                _ReportTile(
                  icon: Icons.account_balance,
                  title: 'Balance Sheet',
                  subtitle: 'Assets, liabilities, equity',
                  color: KColors.secondary,
                  onTap: () => context.go(Routes.balanceSheet),
                ),
                _ReportTile(
                  icon: Icons.menu_book,
                  title: 'General Ledger',
                  subtitle: 'Account-level transactions',
                  color: KColors.info,
                  onTap: () => context.go(Routes.generalLedger),
                ),
              ],
            ),
            KSpacing.vGapXl,

            // AR Reports
            Text('Accounts Receivable', style: KTypography.h2),
            KSpacing.vGapMd,
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: KSpacing.md,
              mainAxisSpacing: KSpacing.md,
              childAspectRatio: 1.4,
              children: [
                _ReportTile(
                  icon: Icons.timelapse,
                  title: 'Ageing Report',
                  subtitle: 'Outstanding receivables by age',
                  color: KColors.warning,
                  onTap: () => context.go(Routes.ageingReport),
                ),
                _ReportTile(
                  icon: Icons.receipt_long,
                  title: 'GSTR-1',
                  subtitle: 'GST outward supplies',
                  color: KColors.accent,
                  onTap: () => context.go(Routes.gst),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ReportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: KSpacing.borderRadiusMd,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          KSpacing.vGapMd,
          Text(title, style: KTypography.labelLarge),
          KSpacing.vGapXs,
          Text(
            subtitle,
            style: KTypography.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
