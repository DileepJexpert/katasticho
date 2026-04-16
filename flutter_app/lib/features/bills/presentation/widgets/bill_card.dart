import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../data/bill_dto.dart';

/// Card used in the bill list. Extracts fields via [BillDto] and
/// navigates to the bill detail screen on tap.
class BillCard extends StatelessWidget {
  final Map<String, dynamic> bill;

  const BillCard({super.key, required this.bill});

  @override
  Widget build(BuildContext context) {
    final b = BillDto(bill);

    return KCard(
      onTap: () {
        if (b.id.isNotEmpty) {
          context.go('/bills/${b.id}');
        }
      },
      child: Row(
        children: [
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
                      color: b.isOverdue
                          ? KColors.error
                          : KColors.textSecondary,
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
                  style: KTypography.bodySmall.copyWith(
                    color: KColors.warning,
                  ),
                ),
              ],
            ],
          ),
          KSpacing.hGapSm,
          const Icon(Icons.chevron_right, color: KColors.textHint),
        ],
      ),
    );
  }
}
