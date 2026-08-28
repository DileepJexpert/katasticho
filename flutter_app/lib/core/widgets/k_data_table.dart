import 'package:flutter/material.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';

/// Column definition for KDataTable.
class KTableColumn {
  final String label;
  final double? width;
  final bool numeric;
  final TextAlign textAlign;

  const KTableColumn({
    required this.label,
    this.width,
    this.numeric = false,
    this.textAlign = TextAlign.start,
  });
}

/// Lightweight data table that wraps Material DataTable with Katasticho styling.
class KDataTable extends StatelessWidget {
  final List<KTableColumn> columns;
  final List<List<Widget>> rows;
  final bool showHeader;
  final VoidCallback? onLoadMore;
  final bool isLoading;
  final ScrollController? scrollController;

  const KDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.showHeader = true,
    this.onLoadMore,
    this.isLoading = false,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: KSpacing.borderRadiusMd,
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.4 : 0.7),
          width: 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width,
          ),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              isDark
                  ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
                  : const Color(0xFFF8F8F6),
            ),
            headingRowHeight: 38,
            dataRowMinHeight: 38,
            dataRowMaxHeight: 46,
            dataRowColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.selected)) {
                return cs.primary.withValues(alpha: 0.08);
              }
              if (states.contains(WidgetState.hovered)) {
                return isDark
                    ? cs.surfaceContainerHighest.withValues(alpha: 0.25)
                    : const Color(0xFFF3F3F1);
              }
              return Colors.transparent;
            }),
            headingTextStyle: KTypography.labelSmall.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
            dataTextStyle: KTypography.bodySmall.copyWith(
              color: cs.onSurface,
            ),
            columnSpacing: 16,
            horizontalMargin: 14,
            dividerThickness: 1.0,
            showBottomBorder: false,
            columns: columns
                .map((col) => DataColumn(
                      label: Text(
                        col.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      numeric: col.numeric,
                    ))
                .toList(),
            rows: rows
                .map((row) => DataRow(
                      cells: row.map((cell) => DataCell(cell)).toList(),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}

/// Simple key-value detail row for detail screens.
class KDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? valueWidget;
  final TextStyle? valueStyle;
  final Widget? trailing;

  const KDetailRow({
    super.key,
    required this.label,
    this.value = '',
    this.valueWidget,
    this.valueStyle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelStyle = KTypography.labelSmall.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        );
        final effectiveValueStyle = valueStyle ??
            KTypography.bodySmall.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            );

        final displayWidget = valueWidget ??
            Text(
              value,
              style: effectiveValueStyle,
              textAlign: constraints.maxWidth < 360 ? TextAlign.start : TextAlign.end,
            );

        if (constraints.maxWidth < 360) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: labelStyle),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: displayWidget),
                    if (trailing != null) ...[
                      KSpacing.hGapSm,
                      trailing!,
                    ],
                  ],
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(label, style: labelStyle),
              ),
              KSpacing.hGapSm,
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: displayWidget,
                ),
              ),
              if (trailing != null) ...[
                KSpacing.hGapSm,
                trailing!,
              ],
            ],
          ),
        );
      },
    );
  }
}
