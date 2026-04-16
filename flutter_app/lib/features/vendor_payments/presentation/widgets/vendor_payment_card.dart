import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../data/vendor_payment_dto.dart';

/// Card used in the vendor payment list.
class VendorPaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;

  const VendorPaymentCard({super.key, required this.payment});

  @override
  Widget build(BuildContext context) {
    final p = VendorPaymentDto(payment);

    return KCard(
      onTap: () {
        if (p.id.isNotEmpty) {
          context.go('/vendor-payments/${p.id}');
        }
      },
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: KColors.success.withValues(alpha: 0.1),
              borderRadius: KSpacing.borderRadiusMd,
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: KColors.success,
              size: 22,
            ),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(p.paymentNumber,
                          style: KTypography.labelLarge),
                    ),
                    KSpacing.hGapSm,
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: KColors.textHint.withValues(alpha: 0.12),
                        borderRadius: KSpacing.borderRadiusXl,
                      ),
                      child: Text(
                        p.paymentModeLabel,
                        style: KTypography.labelSmall.copyWith(
                          color: KColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                KSpacing.vGapXs,
                Text(
                  p.vendorName,
                  style: KTypography.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (p.paymentDate.isNotEmpty) ...[
                  KSpacing.vGapXs,
                  Text(
                    DateFormatter.display(DateTime.parse(p.paymentDate)),
                    style: KTypography.bodySmall.copyWith(
                      color: KColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            CurrencyFormatter.formatIndian(p.amount),
            style: KTypography.amountMedium.copyWith(
              color: KColors.success,
            ),
          ),
          KSpacing.hGapSm,
          const Icon(Icons.chevron_right, color: KColors.textHint),
        ],
      ),
    );
  }
}
