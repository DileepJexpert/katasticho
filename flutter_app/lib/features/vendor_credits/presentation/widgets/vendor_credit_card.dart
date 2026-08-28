import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/vendor_credit_dto.dart';

/// Card used in the vendor credit list. Extracts fields via [VendorCreditDto]
/// and navigates to the vendor credit detail screen on tap.
class VendorCreditCard extends StatelessWidget {
  final Map<String, dynamic> credit;

  const VendorCreditCard({super.key, required this.credit});

  @override
  Widget build(BuildContext context) {
    final c = VendorCreditDto(credit);

    return KCard(
      onTap: () {
        if (c.id.isNotEmpty) {
          context.go('/vendor-credits/${c.id}');
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
                      child:
                          Text(c.creditNumber, style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    KSpacing.hGapSm,
                    KStatusChip(status: c.status),
                  ],
                ),
                KSpacing.vGapXs,
                Text(
                  c.vendorName,
                  style: KTypography.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (c.reason.isNotEmpty) ...[
                  KSpacing.vGapXs,
                  Text(
                    c.reason,
                    style: KTypography.bodySmall.copyWith(
                      color: KColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (c.creditDate.isNotEmpty) ...[
                  KSpacing.vGapXs,
                  Text(
                    c.creditDate,
                    style: KTypography.bodySmall.copyWith(
                      color: KColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              KMoney(c.totalAmount, size: KMoneySize.medium),
              if (c.balance < c.totalAmount && c.balance > 0) ...[
                KSpacing.vGapXs,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Bal: ', style: KTypography.bodySmall.copyWith(color: KColors.warning)),
                    KMoney(c.balance, size: KMoneySize.small, style: const TextStyle(color: KColors.warning)),
                  ],
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
