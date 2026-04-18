import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../data/bill_dto.dart';

class BillCard extends StatelessWidget {
  final Map<String, dynamic> bill;
  final bool selected;
  final bool inSelection;
  final VoidCallback? onToggleSelect;

  const BillCard({
    super.key,
    required this.bill,
    this.selected = false,
    this.inSelection = false,
    this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final b = BillDto(bill);

    return KCard(
      onTap: () {
        if (inSelection) {
          onToggleSelect?.call();
          return;
        }
        if (b.id.isNotEmpty) context.go('/bills/${b.id}');
      },
      onLongPress: onToggleSelect,
      borderColor: selected ? cs.primary : null,
      backgroundColor: selected ? cs.primary.withValues(alpha: 0.06) : null,
      child: Row(
        children: [
          if (inSelection) ...[
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? cs.primary : cs.onSurfaceVariant,
              size: 22,
            ),
            KSpacing.hGapSm,
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(b.billNumber, style: KTypography.labelLarge),
                    ),
                    KSpacing.hGapSm,
                    KStatusChip(status: b.status),
                  ],
                ),
                KSpacing.vGapXs,
                Text(
                  b.vendorName,
                  style: KTypography.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (b.vendorBillNumber.isNotEmpty) ...[
                  KSpacing.vGapXs,
                  Text(
                    'Ref: ${b.vendorBillNumber}',
                    style: KTypography.bodySmall.copyWith(
                      color: KColors.textSecondary,
                    ),
                  ),
                ],
                if (b.dueDate.isNotEmpty) ...[
                  KSpacing.vGapXs,
                  Text(
                    DateFormatter.dueStatus(DateTime.parse(b.dueDate)),
                    style: KTypography.bodySmall.copyWith(
                      color: b.isOverdue ? KColors.error : KColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.formatIndian(b.totalAmount),
                style: KTypography.amountMedium,
              ),
              if (b.balanceDue < b.totalAmount && b.balanceDue > 0) ...[
                KSpacing.vGapXs,
                Text(
                  'Due: ${CurrencyFormatter.formatIndian(b.balanceDue)}',
                  style: KTypography.bodySmall.copyWith(color: KColors.warning),
                ),
              ],
            ],
          ),
          KSpacing.hGapSm,
          if (!inSelection)
            const Icon(Icons.chevron_right, color: KColors.textHint),
        ],
      ),
    );
  }
}
