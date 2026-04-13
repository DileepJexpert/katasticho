import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/item_group_repository.dart';

/// F5 — flat list of variant templates (item groups). Tapping a row
/// drills into the detail screen where variants live.
class ItemGroupListScreen extends ConsumerWidget {
  const ItemGroupListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(itemGroupListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Item Groups')),
      body: groupsAsync.when(
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

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(itemGroupListProvider),
            child: ListView.separated(
              padding: KSpacing.pagePadding,
              itemCount: groups.length,
              separatorBuilder: (_, __) => KSpacing.vGapSm,
              itemBuilder: (context, index) {
                final group = groups[index] as Map<String, dynamic>;
                return _GroupCard(group: group);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/item-groups/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Group'),
      ),
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
