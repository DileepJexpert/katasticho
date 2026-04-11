import 'package:flutter/material.dart';
import '../theme/k_colors.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';

/// Status chip that uses semantic colors based on the status string.
class KStatusChip extends StatelessWidget {
  final String status;
  final String? label;

  const KStatusChip({
    super.key,
    required this.status,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final displayLabel = label ?? _formatStatus(status);
    final color = KColors.statusColor(status);
    final bgColor = KColors.statusBgColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: KSpacing.borderRadiusSm,
      ),
      child: Text(
        displayLabel,
        style: KTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  String _formatStatus(String status) {
    return status.replaceAll('_', ' ').toUpperCase();
  }
}
