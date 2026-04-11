import 'package:flutter/material.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';

class OverdueInvoicesWidget extends StatelessWidget {
  const OverdueInvoicesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder — will be wired to API
    return KCard(
      title: 'Overdue Invoices',
      action: TextButton(
        onPressed: () {},
        child: const Text('View All'),
      ),
      child: const KEmptyState(
        icon: Icons.check_circle_outline,
        title: 'No overdue invoices',
        subtitle: 'All your invoices are up to date!',
      ),
    );
  }
}
