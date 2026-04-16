import 'package:flutter/material.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/utils/currency_formatter.dart';

/// Single search result row — tap to add to cart.
class PosItemSearchResult extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const PosItemSearchResult({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = item['name'] as String? ?? '';
    final sku = item['sku'] as String? ?? '';
    final rate = (item['rate'] as num?)?.toDouble() ?? 0;
    final stock = (item['currentStock'] as num?)?.toDouble() ?? 0;
    final unit = item['unit'] as String? ?? 'PCS';
    final barcode = item['barcode'] as String?;

    return InkWell(
      onTap: onTap,
      borderRadius: KSpacing.borderRadiusMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: KSpacing.borderRadiusMd,
              ),
              child: Icon(Icons.inventory_2_outlined,
                  size: 20, color: cs.primary),
            ),
            KSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: KTypography.labelMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(sku,
                          style: KTypography.bodySmall
                              .copyWith(color: KColors.textSecondary)),
                      if (barcode != null && barcode.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.qr_code, size: 12, color: KColors.textHint),
                        const SizedBox(width: 2),
                        Text(barcode,
                            style: KTypography.labelSmall
                                .copyWith(color: KColors.textHint)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(CurrencyFormatter.formatIndian(rate),
                    style: KTypography.amountSmall),
                Text('${stock.toStringAsFixed(0)} $unit',
                    style: KTypography.labelSmall.copyWith(
                      color: stock > 0 ? KColors.success : KColors.error,
                    )),
              ],
            ),
            KSpacing.hGapSm,
            Icon(Icons.add_circle_outline, size: 20, color: cs.primary),
          ],
        ),
      ),
    );
  }
}
