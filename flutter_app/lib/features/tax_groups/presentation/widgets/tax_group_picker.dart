import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_typography.dart';
import '../../data/tax_group_repository.dart';

/// Reusable dropdown that loads tax groups once (cached via [taxGroupsProvider])
/// and lets the user pick one.
///
/// Displays: tax group name + total percentage, e.g. "GST 18%", "IGST 18%".
///
/// Used in:
///   - Invoice create screen line items
///   - Bill create screen line items
///   - Vendor credit create screen line items
///   - Item create/edit
class TaxGroupPicker extends ConsumerWidget {
  /// Currently selected tax group ID (null = none selected).
  final String? value;

  /// Called when a tax group is selected. Returns the [TaxGroupDto].
  final ValueChanged<TaxGroupDto?> onChanged;

  /// Label for the dropdown field.
  final String label;

  const TaxGroupPicker({
    super.key,
    this.value,
    required this.onChanged,
    this.label = 'Tax Group',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taxGroupsAsync = ref.watch(taxGroupsProvider);

    return taxGroupsAsync.when(
      loading: () => DropdownButtonFormField<String>(
        value: null,
        decoration: InputDecoration(labelText: label),
        items: const [],
        onChanged: null,
        hint: const Text('Loading...'),
      ),
      error: (_, __) => DropdownButtonFormField<String>(
        value: null,
        decoration: InputDecoration(
          labelText: label,
          errorText: 'Failed to load',
        ),
        items: const [],
        onChanged: null,
      ),
      data: (groups) {
        final activeGroups = groups.where((g) => g.active).toList();

        return DropdownButtonFormField<String>(
          value: value != null &&
                  activeGroups.any((g) => g.id == value)
              ? value
              : null,
          decoration: InputDecoration(labelText: label),
          isExpanded: true,
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('None (0%)'),
            ),
            ...activeGroups.map((group) => DropdownMenuItem<String>(
                  value: group.id,
                  child: _TaxGroupItem(group: group),
                )),
          ],
          onChanged: (selectedId) {
            if (selectedId == null) {
              onChanged(null);
            } else {
              final selected =
                  activeGroups.firstWhere((g) => g.id == selectedId);
              onChanged(selected);
            }
          },
          selectedItemBuilder: (context) => [
            const Text('None (0%)'),
            ...activeGroups.map((group) => Text(
                  group.displayLabel,
                  overflow: TextOverflow.ellipsis,
                )),
          ],
        );
      },
    );
  }
}

class _TaxGroupItem extends StatelessWidget {
  final TaxGroupDto group;

  const _TaxGroupItem({required this.group});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(group.displayLabel, style: KTypography.bodyMedium),
              if (group.rates.length > 1)
                Text(
                  group.rates.map((r) => '${r.name} ${r.rate}%').join(' + '),
                  style: KTypography.bodySmall.copyWith(
                    color: KColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
