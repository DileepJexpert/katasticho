import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/price_list_repository.dart';

class PriceListListScreen extends ConsumerWidget {
  const PriceListListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(priceListsProvider);

    return Scaffold(
      body: Column(
        children: [
          const KListPageHeader(title: 'Price Lists'),
          Expanded(
            child: listsAsync.when(
              loading: () => const KShimmerList(),
              error: (err, st) {
                debugPrint('[PriceListList] ERROR: $err\n$st');
                return KErrorView(
                  message: 'Failed to load price lists',
                  onRetry: () => ref.invalidate(priceListsProvider),
                );
              },
              data: (lists) {
                if (lists.isEmpty) {
                  return KEmptyState(
                    icon: Icons.sell_outlined,
                    title: 'No price lists yet',
                    subtitle:
                        'Create a price list to apply tiered pricing to customers automatically at invoice time.',
                    actionLabel: 'Create Price List',
                    onAction: () => context.go('/price-lists/create'),
                  );
                }

                return KResponsiveEntityList<Map<String, dynamic>>(
                  items: lists,
                  onRefresh: () async => ref.invalidate(priceListsProvider),
                  mobileItemBuilder: (context, list) =>
                      _PriceListCard(list: list),
                  tableBuilder: (context) => _PriceListTable(lists: lists),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/price-lists/create'),
        icon: const Icon(Icons.add),
        label: const Text('New List'),
        tooltip: 'New List (N)',
      ),
    );
  }
}

class _PriceListTable extends StatelessWidget {
  final List<Map<String, dynamic>> lists;

  const _PriceListTable({required this.lists});

  @override
  Widget build(BuildContext context) {
    return KEntityDataTable(
      columnSpacing: 22,
      horizontalMargin: 14,
      columns: const [
        DataColumn(label: Text('Name')),
        DataColumn(label: Text('Description')),
        DataColumn(label: Text('Currency')),
        DataColumn(label: Text('Default')),
        DataColumn(label: Text('Status')),
        DataColumn(label: SizedBox(width: 32, child: Text(''))),
      ],
      rows: lists.map((list) {
        final id = list['id']?.toString() ?? '';
        final name = list['name']?.toString() ?? 'Unnamed list';
        final currency = list['currency']?.toString() ?? 'INR';
        final description = list['description']?.toString() ?? '--';
        final isDefault = list['isDefault'] == true;
        final active = list['active'] != false;

        return DataRow(
          color: kEntityRowColor(context),
          onSelectChanged: (_) {
            if (id.isNotEmpty) context.go('/price-lists/$id');
          },
          cells: [
            DataCell(KTablePrimaryTextCell(value: name, width: 190)),
            DataCell(KTableTextCell(value: description, width: 280)),
            DataCell(Text(currency)),
            DataCell(Icon(
              isDefault
                  ? Icons.check_circle_rounded
                  : Icons.remove_circle_outline,
              color: isDefault ? KColors.primary : KColors.textHint,
              size: 18,
            )),
            DataCell(_Pill(
              label: active ? 'Active' : 'Inactive',
              color: active ? KColors.success : KColors.textSecondary,
            )),
            DataCell(KTableOpenActionCell(
              tooltip: 'Open price list',
              onPressed: id.isEmpty ? null : () => context.go('/price-lists/$id'),
            )),
          ],
        );
      }).toList(),
    );
  }
}

class _PriceListCard extends StatelessWidget {
  final Map<String, dynamic> list;
  const _PriceListCard({required this.list});

  @override
  Widget build(BuildContext context) {
    final id = list['id']?.toString();
    final name = list['name']?.toString() ?? 'Unnamed list';
    final currency = list['currency']?.toString() ?? 'INR';
    final description = list['description']?.toString() ?? '';
    final isDefault = list['isDefault'] == true;
    final active = list['active'] != false;

    return KCard(
      onTap: id == null ? null : () => context.go('/price-lists/$id'),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: KColors.primaryLight.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.sell_outlined,
                color: KColors.primary, size: 22),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name,
                          style: KTypography.labelLarge,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (isDefault) ...[
                      KSpacing.hGapSm,
                      _Pill(label: 'Default', color: KColors.primary),
                    ],
                    if (!active) ...[
                      KSpacing.hGapSm,
                      _Pill(label: 'Inactive', color: KColors.textSecondary),
                    ],
                  ],
                ),
                if (description.isNotEmpty) ...[
                  KSpacing.vGapXs,
                  Text(description,
                      style: KTypography.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
                KSpacing.vGapXs,
                Text('Currency: $currency', style: KTypography.labelSmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: KColors.textHint),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: KTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
