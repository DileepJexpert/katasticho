import 'package:flutter/material.dart';

import '../theme/k_colors.dart';
import '../theme/k_typography.dart';
import '../utils/currency_formatter.dart';

/// Size presets for [KMoney], mapping to the tabular-figure `amount*` styles.
enum KMoneySize { small, medium, large }

/// Right-aligned money cell that **enforces** Indian ₹ grouping + tabular
/// (lining) numerals by construction — so call sites can't forget the
/// `FontFeature.tabularFigures()` that keeps ₹ columns aligned (design-system.md
/// §4 "numbers are sacred"). Wraps the existing [CurrencyFormatter] for the
/// string, so the two coexist and money cells migrate to [KMoney]
/// opportunistically.
///
/// `colorBySign` is **off by default** — most ledger amounts are neutral; a
/// debit is not "bad". Turn it on only where negative genuinely means
/// money-out / loss / overdue (design-system.md §2 accounting nuance).
class KMoney extends StatelessWidget {
  final num value;

  /// Two decimals when true (amounts); whole rupees when false (counts/totals).
  final bool decimals;

  /// Compact lakh/crore form for dashboards & summary tiles (₹1.23 Cr).
  final bool compact;

  /// Colour positive green / negative red. Default false (neutral ink).
  final bool colorBySign;

  final KMoneySize size;

  /// Extra style overrides merged on top of the resolved amount style
  /// (e.g. a custom colour). Tabular figures + right-align are preserved.
  final TextStyle? style;

  const KMoney(
    this.value, {
    super.key,
    this.decimals = true,
    this.compact = false,
    this.colorBySign = false,
    this.size = KMoneySize.small,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final base = switch (size) {
      KMoneySize.large => KTypography.amountLarge,
      KMoneySize.medium => KTypography.amountMedium,
      KMoneySize.small => KTypography.amountSmall,
    };

    final v = value.toDouble();
    final text = compact
        ? CurrencyFormatter.formatCompact(v)
        : CurrencyFormatter.formatIndian(v);

    Color? signColor;
    if (colorBySign) {
      signColor = v < 0
          ? KColors.error
          : (v > 0 ? KColors.success : null);
    }

    // Inherit the default foreground when no sign/style colour is supplied so
    // it adapts to light/dark mode (the amount styles intentionally set no colour).
    final resolved = base
        .copyWith(color: signColor)
        .merge(style);

    return Text(
      text,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: resolved,
    );
  }
}
