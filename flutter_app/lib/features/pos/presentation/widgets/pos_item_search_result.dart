import 'package:flutter/material.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/utils/currency_formatter.dart';

/// Single search result row — tap to add to cart.
/// Shows stock badges (out-of-stock, low stock) and expiry warnings.
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
    final expiryStr = item['batchExpiryDate'] as String?;
    final taxGroupName = item['taxGroupName'] as String?;

    final isOutOfStock = stock <= 0;
    final expiryStatus = _expiryStatus(expiryStr);

    return Opacity(
      opacity: isOutOfStock ? 0.5 : 1.0,
      child: InkWell(
        onTap: isOutOfStock ? null : onTap,
        borderRadius: KSpacing.borderRadiusMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isOutOfStock
                      ? cs.outlineVariant.withValues(alpha: 0.3)
                      : cs.primary.withValues(alpha: 0.1),
                  borderRadius: KSpacing.borderRadiusMd,
                ),
                child: Icon(Icons.inventory_2_outlined,
                    size: 20,
                    color: isOutOfStock ? cs.outlineVariant : cs.primary),
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
                          Icon(Icons.qr_code,
                              size: 12, color: KColors.textHint),
                          const SizedBox(width: 2),
                          Text(barcode,
                              style: KTypography.labelSmall
                                  .copyWith(color: KColors.textHint)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Badges row
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _StockBadge(stock: stock, unit: unit),
                        if (taxGroupName != null && taxGroupName.isNotEmpty)
                          _Badge(
                            label: taxGroupName,
                            color: KColors.info,
                            bgColor: KColors.infoLight,
                          ),
                        if (expiryStatus != null)
                          _Badge(
                            label: expiryStatus.label,
                            color: expiryStatus.color,
                            bgColor: expiryStatus.bgColor,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              KSpacing.hGapSm,
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CurrencyFormatter.formatIndian(rate),
                      style: KTypography.amountSmall),
                ],
              ),
              KSpacing.hGapSm,
              Icon(Icons.add_circle_outline,
                  size: 20,
                  color: isOutOfStock ? cs.outlineVariant : cs.primary),
            ],
          ),
        ),
      ),
    );
  }

  _ExpiryInfo? _expiryStatus(String? expiryStr) {
    if (expiryStr == null || expiryStr.isEmpty) return null;
    try {
      final expiry = DateTime.parse(expiryStr);
      final now = DateTime.now();
      final daysUntil = expiry.difference(now).inDays;

      if (daysUntil < 0) {
        return _ExpiryInfo(
          label: 'Expired',
          color: KColors.error,
          bgColor: KColors.errorLight,
        );
      } else if (daysUntil <= 30) {
        return _ExpiryInfo(
          label: 'Exp ${daysUntil}d',
          color: KColors.warning,
          bgColor: KColors.warningLight,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

class _ExpiryInfo {
  final String label;
  final Color color;
  final Color bgColor;
  const _ExpiryInfo(
      {required this.label, required this.color, required this.bgColor});
}

class _StockBadge extends StatelessWidget {
  final double stock;
  final String unit;

  const _StockBadge({required this.stock, required this.unit});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final Color bgColor;
    final String label;

    if (stock <= 0) {
      color = KColors.error;
      bgColor = KColors.errorLight;
      label = 'Out of stock';
    } else if (stock <= 5) {
      color = KColors.warning;
      bgColor = KColors.warningLight;
      label = '${stock.toStringAsFixed(0)} $unit left';
    } else {
      color = KColors.success;
      bgColor = KColors.successLight;
      label = '${stock.toStringAsFixed(0)} $unit';
    }

    return _Badge(label: label, color: color, bgColor: bgColor);
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;

  const _Badge({
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: KTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}
