import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_typography.dart';
import '../data/dashboard_repository.dart';

/// Dropdown selector for filtering the dashboard by branch. The special
/// value `null` represents "All branches" and is the default.
///
/// Writes to [dashboardFilterProvider] so every downstream aggregation
/// (KPIs, revenue-by-branch, top-selling) re-fetches when selection
/// changes. Loading/error/empty states render inline so the dashboard
/// never flashes a half-broken control.
class BranchSelectorWidget extends ConsumerWidget {
  const BranchSelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(branchesProvider);
    final filter = ref.watch(dashboardFilterProvider);
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: branchesAsync.when(
        loading: () => const _Placeholder(label: 'Loading branches...'),
        error: (_, __) => const _Placeholder(label: 'Branches unavailable'),
        data: (branches) {
          // Don't bother showing a selector when there's only one or
          // zero branches — nothing to pick between.
          if (branches.length < 2) {
            return _Placeholder(
              label: branches.isEmpty
                  ? 'No branches yet'
                  : branches.first.name,
            );
          }

          return Row(
            children: [
              Icon(Icons.store_mall_directory_outlined,
                  size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: filter.branchId,
                    isExpanded: true,
                    hint: Text('All branches', style: KTypography.bodyMedium),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All branches', style: KTypography.bodyMedium),
                      ),
                      for (final b in branches)
                        DropdownMenuItem<String?>(
                          value: b.id,
                          child: Text(b.name, style: KTypography.bodyMedium),
                        ),
                    ],
                    onChanged: (value) {
                      ref.read(dashboardFilterProvider.notifier).state =
                          filter.copyWith(branchId: value);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String label;
  const _Placeholder({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.store_mall_directory_outlined,
            size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(label, style: KTypography.bodyMedium.copyWith(
          color: cs.onSurfaceVariant,
        )),
      ],
    );
  }
}
