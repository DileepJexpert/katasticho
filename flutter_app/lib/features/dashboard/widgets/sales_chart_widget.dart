import 'package:flutter/material.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';

class SalesChartWidget extends StatelessWidget {
  const SalesChartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder chart — will integrate fl_chart when data available
    return KCard(
      title: 'Revenue This Week',
      action: DropdownButton<String>(
        value: 'This Week',
        underline: const SizedBox(),
        style: KTypography.labelMedium,
        items: const [
          DropdownMenuItem(value: 'This Week', child: Text('This Week')),
          DropdownMenuItem(value: 'This Month', child: Text('This Month')),
          DropdownMenuItem(value: 'This Quarter', child: Text('This Quarter')),
        ],
        onChanged: (v) {},
      ),
      child: SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bar_chart,
                size: 48,
                color: KColors.primary.withValues(alpha: 0.3),
              ),
              KSpacing.vGapSm,
              Text(
                'Chart will appear when data is available',
                style: KTypography.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
