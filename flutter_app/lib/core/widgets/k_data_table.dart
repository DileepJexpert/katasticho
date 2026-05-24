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
    return SingleChildScrollView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width,
        ),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            cs.surfaceContainerHighest.withValues(alpha: 0.5),
          ),
          headingRowHeight: 38,
          dataRowMinHeight: 38,
          dataRowMaxHeight: 46,
          headingTextStyle: KTypography.labelMedium.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
          dataTextStyle: KTypography.bodySmall.copyWith(color: cs.onSurface),
          columnSpacing: 10,
          horizontalMargin: 8,
          dividerThickness: 0.5,
          columns: columns
              .map((col) => DataColumn(
                    label: Text(col.label),
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
    );
  }
}

/// Simple key-value detail row for detail screens.
class KDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;
  final Widget? trailing;

  const KDetailRow({
    super.key,
    required this.label,
    required this.value,
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
                    Expanded(child: Text(value, style: effectiveValueStyle)),
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
                width: 116,
                child: Text(label, style: labelStyle),
              ),
              KSpacing.hGapSm,
              Expanded(
                child: Text(
                  value,
                  style: effectiveValueStyle,
                  textAlign: TextAlign.end,
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
