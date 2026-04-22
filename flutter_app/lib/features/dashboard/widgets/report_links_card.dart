import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';

class ReportLinksCard extends StatelessWidget {
  const ReportLinksCard({super.key});

  static const _links = [
    _ReportLink('Profit & Loss', Icons.bar_chart_rounded, '/reports/profit-loss', KColors.primary),
    _ReportLink('Balance Sheet', Icons.account_balance_rounded, '/reports/balance-sheet', KColors.secondary),
    _ReportLink('Trial Balance', Icons.summarize_rounded, '/reports/trial-balance', KColors.warning),
    _ReportLink('AR Aging', Icons.account_balance_wallet_outlined, '/reports/ageing', KColors.error),
    _ReportLink('AP Aging', Icons.payment_outlined, '/reports/ap-ageing', KColors.accent),
    _ReportLink('General Ledger', Icons.menu_book_outlined, '/reports/general-ledger', KColors.success),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return KCard(
      title: 'Quick Reports',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _links.map((link) => ActionChip(
          avatar: Icon(link.icon, size: 16, color: link.color),
          label: Text(link.label, style: KTypography.labelSmall),
          backgroundColor: link.color.withValues(alpha: 0.08),
          side: BorderSide(color: link.color.withValues(alpha: 0.2)),
          onPressed: () => context.go(link.route),
        )).toList(),
      ),
    );
  }
}

class _ReportLink {
  final String label;
  final IconData icon;
  final String route;
  final Color color;

  const _ReportLink(this.label, this.icon, this.route, this.color);
}
