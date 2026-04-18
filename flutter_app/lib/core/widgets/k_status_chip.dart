import 'package:flutter/material.dart';
import '../theme/k_colors.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';

/// Status chip that uses semantic colors based on the status string.
///
/// Pill-shaped, with a colored dot indicator on the left for quick scanning.
class KStatusChip extends StatelessWidget {
  final String status;
  final String? label;
  final bool dense;

  const KStatusChip({
    super.key,
    required this.status,
    this.label,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayLabel = label ?? _formatStatus(status);
    final color = KColors.statusColor(status);
    final bgColor = KColors.statusBgColor(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(KSpacing.radiusRound),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            displayLabel,
            overflow: TextOverflow.ellipsis,
            style: KTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              fontSize: dense ? 10 : 11,
            ),
          ),
        ],
      ),
    );
  }

  String _formatStatus(String status) {
    return status.replaceAll('_', ' ').toUpperCase();
  }
}
