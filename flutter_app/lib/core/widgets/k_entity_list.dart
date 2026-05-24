import 'package:flutter/material.dart';

import '../theme/k_colors.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';
import 'k_card.dart';
import 'k_status_chip.dart';

typedef KEntityItemBuilder<T> = Widget Function(BuildContext context, T item);

/// Responsive list wrapper for ERP list pages.
///
/// Keeps the common mobile-card vs desktop-table switch in one place while
/// each feature still owns its domain-specific card and table columns.
class KResponsiveEntityList<T> extends StatelessWidget {
  final List<T> items;
  final KEntityItemBuilder<T> mobileItemBuilder;
  final WidgetBuilder tableBuilder;
  final Future<void> Function()? onRefresh;
  final double breakpoint;
  final EdgeInsetsGeometry mobilePadding;
  final double mobileSpacing;

  const KResponsiveEntityList({
    super.key,
    required this.items,
    required this.mobileItemBuilder,
    required this.tableBuilder,
    this.onRefresh,
    this.breakpoint = KSpacing.tabletBreakpoint,
    this.mobilePadding = KSpacing.pagePadding,
    this.mobileSpacing = KSpacing.sm,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= breakpoint) {
          return tableBuilder(context);
        }

        return ListView.separated(
          padding: mobilePadding,
          itemCount: items.length,
          separatorBuilder: (_, __) => SizedBox(height: mobileSpacing),
          itemBuilder: (context, index) =>
              mobileItemBuilder(context, items[index]),
        );
      },
    );

    if (onRefresh != null) {
      child = RefreshIndicator(onRefresh: onRefresh!, child: child);
    }

    return child;
  }
}

/// Styled table shell used by ERP entity list pages.
class KEntityDataTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final double columnSpacing;
  final double horizontalMargin;
  final double dataRowMinHeight;
  final double dataRowMaxHeight;

  const KEntityDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.columnSpacing = 12,
    this.horizontalMargin = 10,
    this.dataRowMinHeight = 42,
    this.dataRowMaxHeight = 50,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return KCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: KSpacing.borderRadiusLg,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowHeight: 38,
                      dataRowMinHeight: dataRowMinHeight,
                      dataRowMaxHeight: dataRowMaxHeight,
                      columnSpacing: columnSpacing,
                      horizontalMargin: horizontalMargin,
                      headingRowColor: WidgetStatePropertyAll(
                        cs.surfaceContainerHighest.withValues(alpha: 0.55),
                      ),
                      headingTextStyle: KTypography.labelMedium.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                      dataTextStyle: KTypography.bodyMedium.copyWith(
                        color: cs.onSurface,
                      ),
                      columns: columns,
                      rows: rows,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

WidgetStateProperty<Color?> kEntityRowColor(
  BuildContext context, {
  bool selected = false,
}) {
  final cs = Theme.of(context).colorScheme;
  return WidgetStateProperty.resolveWith((states) {
    if (selected) {
      return cs.primary.withValues(alpha: 0.07);
    }
    if (states.contains(WidgetState.hovered)) {
      return cs.surfaceContainerHighest.withValues(alpha: 0.35);
    }
    return null;
  });
}

class KTableSelectionCell extends StatelessWidget {
  final bool selected;
  final ValueChanged<bool?>? onChanged;

  const KTableSelectionCell({
    super.key,
    required this.selected,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: selected,
      visualDensity: VisualDensity.compact,
      onChanged: onChanged,
    );
  }
}

class KTablePrimaryTextCell extends StatelessWidget {
  final String value;
  final double? width;

  const KTablePrimaryTextCell({
    super.key,
    required this.value,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final child = Text(
      value,
      style: KTypography.labelLarge.copyWith(
        color: cs.primary,
        fontWeight: FontWeight.w700,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (width == null) return child;
    return SizedBox(width: width, child: child);
  }
}

class KTableTextCell extends StatelessWidget {
  final String value;
  final double? width;
  final TextStyle? style;

  const KTableTextCell({
    super.key,
    required this.value,
    this.width,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final child = Text(
      value,
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (width == null) return child;
    return SizedBox(width: width, child: child);
  }
}

class KTableDateCell extends StatelessWidget {
  final String? value;

  const KTableDateCell({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const Text('--');
    return Text(DateFormatter.short(DateTime.parse(value!)));
  }
}

class KTableDueDateCell extends StatelessWidget {
  final String? value;
  final bool overdue;

  const KTableDueDateCell({
    super.key,
    required this.value,
    this.overdue = false,
  });

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const Text('--');

    return Text(
      DateFormatter.dueStatus(DateTime.parse(value!)),
      style: KTypography.bodySmall.copyWith(
        color: overdue ? KColors.error : KColors.textSecondary,
        fontWeight: overdue ? FontWeight.w700 : FontWeight.w400,
      ),
    );
  }
}

class KTableAmountCell extends StatelessWidget {
  final double value;
  final Color? color;

  const KTableAmountCell({
    super.key,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      CurrencyFormatter.formatIndian(value),
      style: KTypography.amountSmall.copyWith(
        color: color ?? Theme.of(context).colorScheme.onSurface,
      ),
      textAlign: TextAlign.end,
    );
  }
}

class KTableOpenActionCell extends StatelessWidget {
  final String tooltip;
  final VoidCallback? onPressed;

  const KTableOpenActionCell({
    super.key,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: const Icon(Icons.chevron_right, size: 18),
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}

class KTableStatusCell extends StatelessWidget {
  final String status;

  const KTableStatusCell({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return KStatusChip(status: status);
  }
}
