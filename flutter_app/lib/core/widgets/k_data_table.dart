import 'package:flutter/material.dart';
import '../theme/k_colors.dart';
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
    return SingleChildScrollView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width,
        ),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            KColors.primary.withValues(alpha: 0.04),
          ),
          headingTextStyle: KTypography.labelLarge.copyWith(
            color: KColors.textSecondary,
          ),
          dataTextStyle: KTypography.bodyMedium,
          columnSpacing: KSpacing.md,
          horizontalMargin: KSpacing.md,
          dividerThickness: 0.5,
          columns: columns
              .map((col) => DataColumn(
                    label: Text(col.label),
                    numeric: col.numeric,
                  ))
              .toList(),
          rows: rows
              .map((row) => DataRow(
                    cells: row
                        .map((cell) => DataCell(cell))
                        .toList(),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: KTypography.bodySmall.copyWith(
                color: KColors.textSecondary,
              ),
            ),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Text(
              value,
              style: valueStyle ?? KTypography.bodyMedium,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
