import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/item_group_repository.dart';

class ItemGroupListScreen extends ConsumerWidget {
  const ItemGroupListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(itemGroupListProvider);

    return KKeyboardListWrapper(
      itemCount: () => groupsAsync.valueOrNull != null
          ? ((groupsAsync.valueOrNull!['data'] is List
                  ? groupsAsync.valueOrNull!['data'] as List
                  : (groupsAsync.valueOrNull!['data'] is Map
                      ? (groupsAsync.valueOrNull!['data']['content'] as List?) ?? []
                      : [])))
              .length
          : 0,
      onNew: () => context.push('/item-groups/create'),
      onRefresh: () => ref.invalidate(itemGroupListProvider),
      onOpen: (index) {
        final data = groupsAsync.valueOrNull?['data'];
        final groups = data is List
            ? data
            : (data is Map ? (data['content'] as List?) ?? [] : []);
        if (index >= 0 && index < groups.length) {
          final id = (groups[index] as Map?)?['id']?.toString();
          if (id != null) context.push('/item-groups/$id');
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            const KListPageHeader(title: 'Item Groups'),
            Expanded(
              child: groupsAsync.when(
                loading: () => const KShimmerList(),
                error: (err, st) {
                  debugPrint('[ItemGroupListScreen] ERROR: $err\n$st');
                  return KErrorView(
                    message: 'Failed to load item groups',
                    onRetry: () => ref.invalidate(itemGroupListProvider),
                  );
                },
                data: (data) {
                  final content = data['data'];
                  final groups = content is List
                      ? content
                      : (content is Map ? (content['content'] as List?) ?? [] : []);

                  if (groups.isEmpty) {
                    return KEmptyState(
                      icon: Icons.category_outlined,
                      title: 'No item groups yet',
                      subtitle:
                          'Group similar items (e.g. T-Shirt) and let the matrix tool mint every size + colour variant in one click.',
                      actionLabel: 'Create Group',
                      onAction: () => context.push('/item-groups/create'),
                    );
                  }

                  final groupMaps = groups
                      .whereType<Map>()
                      .map((group) => group.cast<String, dynamic>())
                      .toList();

                  return KResponsiveEntityList<Map<String, dynamic>>(
                    items: groupMaps,
                    onRefresh: () async => ref.invalidate(itemGroupListProvider),
                    mobileItemBuilder: (context, group) =>
                        _GroupCard(group: group),
                    tableBuilder: (context) => _GroupTable(groups: groupMaps),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/item-groups/create'),
          icon: const Icon(Icons.add),
          label: const Text('New Group'),
          tooltip: 'New Group (N)',
        ),
      ),
    );
  }
}

class _GroupTable extends StatelessWidget {
  final List<Map<String, dynamic>> groups;

  const _GroupTable({required this.groups});

  @override
  Widget build(BuildContext context) {
    return KEntityDataTable(
      columnSpacing: 22,
      horizontalMargin: 14,
      columns: const [
        DataColumn(label: Text('Group')),
        DataColumn(label: Text('SKU Prefix')),
        DataColumn(label: Text('Variants')),
        DataColumn(label: Text('Attributes')),
        DataColumn(label: SizedBox(width: 32, child: Text(''))),
      ],
      rows: groups.map((group) {
        final id = group['id']?.toString() ?? '';
        final name = group['name']?.toString() ?? '--';
        final skuPrefix = group['skuPrefix']?.toString() ?? '--';
        final variantCount = (group['variantCount'] as num?)?.toInt() ?? 0;
        final defs = (group['attributeDefinitions'] as List?) ?? const [];
        final attributes = defs.map((d) {
          final def = d as Map<String, dynamic>;
          final key = def['key']?.toString() ?? '';
          final values = (def['values'] as List?) ?? const [];
          return '$key (${values.length})';
        }).where((value) => value.trim() != '()').join(', ');

        return DataRow(
          color: kEntityRowColor(context),
          onSelectChanged: (_) {
            if (id.isNotEmpty) context.push('/item-groups/$id');
          },
          cells: [
            DataCell(KTablePrimaryTextCell(value: name, width: 210)),
            DataCell(KTableTextCell(value: skuPrefix, width: 130)),
            DataCell(Text('$variantCount')),
            DataCell(KTableTextCell(
              value: attributes.isEmpty ? '--' : attributes,
              width: 320,
            )),
            DataCell(KTableOpenActionCell(
              tooltip: 'Open item group',
              onPressed: id.isEmpty ? null : () => context.push('/item-groups/$id'),
            )),
          ],
        );
      }).toList(),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final id = group['id']?.toString();
    final name = group['name']?.toString() ?? '';
    final skuPrefix = group['skuPrefix']?.toString();
    final variantCount = (group['variantCount'] as num?)?.toInt() ?? 0;
    final defs = (group['attributeDefinitions'] as List?) ?? const [];

    return KCard(
      onTap: () {
        if (id != null) context.push('/item-groups/$id');
      },
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: KColors.primaryLight.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.category_outlined, color: KColors.primary),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: KTypography.labelLarge),
                KSpacing.vGapXs,
                Text(
                  skuPrefix == null || skuPrefix.isEmpty
                      ? '$variantCount variants'
                      : 'SKU: $skuPrefix • $variantCount variants',
                  style: KTypography.bodySmall,
                ),
                if (defs.isNotEmpty) ...[
                  KSpacing.vGapXs,
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: defs.take(3).map<Widget>((d) {
                      final def = d as Map<String, dynamic>;
                      final key = def['key']?.toString() ?? '';
                      final values = (def['values'] as List?) ?? const [];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: KColors.primaryLight.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$key (${values.length})',
                          style: KTypography.labelSmall,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: KColors.textHint),
        ],
      ),
    );
  }
}
