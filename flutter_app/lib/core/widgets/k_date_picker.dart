import 'package:flutter/material.dart';
import '../theme/k_typography.dart';
import '../utils/date_formatter.dart';

/// Date picker field that opens a Material date picker on tap.
class KDatePicker extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool enabled;
  final bool isRequired;

  const KDatePicker({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.enabled = true,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: enabled ? () => _showPicker(context) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label.isNotEmpty)
            Text.rich(
              TextSpan(
                text: label,
                style: KTypography.labelLarge.copyWith(color: cs.onSurface),
                children: isRequired
                    ? [
                        TextSpan(
                          text: ' *',
                          style: KTypography.labelLarge.copyWith(color: cs.error),
                        ),
                      ]
                    : [],
              ),
            ),
          if (label.isNotEmpty) const SizedBox(height: 6),
          InputDecorator(
            decoration: InputDecoration(
              suffixIcon: const Icon(Icons.calendar_today, size: 20),
              enabled: enabled,
            ),
            child: Text(
              value != null ? DateFormatter.display(value!) : 'Select date',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: value != null ? cs.onSurface : cs.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime(2030),
    );
    if (picked != null) {
      onChanged(picked);
    }
  }
}

/// Date range picker for reports.
class KDateRangePicker extends StatelessWidget {
  final String label;
  final DateTimeRange? value;
  final ValueChanged<DateTimeRange> onChanged;

  const KDateRangePicker({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.date_range, size: 20),
        ),
        child: Text(
          value != null
              ? '${DateFormatter.display(value!.start)} - ${DateFormatter.display(value!.end)}'
              : 'Select date range',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: value != null ? cs.onSurface : cs.onSurfaceVariant,
              ),
        ),
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: value,
    );
    if (picked != null) {
      onChanged(picked);
    }
  }
}
