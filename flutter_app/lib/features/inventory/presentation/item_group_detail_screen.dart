import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/item_group_repository.dart';

/// Detail view for an item group. Shows the template's defaults +
/// attribute definitions, then lists every variant under the group as
/// regular item rows. From here the operator can:
///  - Edit the group itself
///  - Delete the group (only when no variants remain)
///  - Open the matrix bulk-create flow
///  - Tap a variant to drill into the underlying Item detail screen.
class ItemGroupDetailScreen extends ConsumerWidget {
  final String groupId;
  const ItemGroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(itemGroupDetailProvider(groupId));
    final variantsAsync = ref.watch(itemGroupVariantsProvider(groupId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Group'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/item-groups/$groupId/edit'),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete group?'),
                    content: const Text(
                        'A group can only be deleted once all its variants have been removed.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
                try {
                  await ref
                      .read(itemGroupRepositoryProvider)
                      .deleteGroup(groupId);
                  ref.invalidate(itemGroupListProvider);
                  if (context.mounted) context.pop();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Delete failed: $e')),
                    );
                  }
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: groupAsync.when(
        loading: () => const KLoading(),
        error: (err, st) {
          debugPrint('[ItemGroupDetail] ERROR: $err\n$st');
          return KErrorView(
            message: 'Failed to load group',
            onRetry: () => ref.invalidate(itemGroupDetailProvider(groupId)),
          );
        },
        data: (raw) {
          final group = (raw['data'] ?? raw) as Map<String, dynamic>;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(itemGroupDetailProvider(groupId));
              ref.invalidate(itemGroupVariantsProvider(groupId));
            },
            child: ListView(
              padding: KSpacing.pagePadding,
              children: [
                _GroupHeader(group: group),
                KSpacing.vGapLg,
                _AttributeDefinitionsCard(group: group),
                KSpacing.vGapLg,
                Row(
                  children: [
                    Expanded(
                      child: Text('Variants', style: KTypography.h3),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          context.push('/item-groups/$groupId/generate-variants'),
                      icon: const Icon(Icons.grid_view, size: 18),
                      label: const Text('Generate Matrix'),
                    ),
                  ],
                ),
                KSpacing.vGapSm,
                variantsAsync.when(
                  loading: () => const KShimmerList(),
                  error: (err, st) => KErrorView(
                    message: 'Failed to load variants',
                    onRetry: () =>
                        ref.invalidate(itemGroupVariantsProvider(groupId)),
                  ),
                  data: (variants) {
                    if (variants.isEmpty) {
                      return KCard(
                        child: Padding(
                          padding: const EdgeInsets.all(KSpacing.md),
                          child: Column(
                            children: [
                              const Icon(Icons.inventory_2_outlined,
                                  size: 36, color: KColors.textHint),
                              KSpacing.vGapSm,
                              Text(
                                'No variants yet',
                                style: KTypography.labelLarge,
                              ),
                              KSpacing.vGapXs,
                              Text(
                                'Use "Generate Matrix" to mint every combination of the attributes above in one click.',
                                style: KTypography.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: variants.map<Widget>((v) {
                        final variant = v as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: KSpacing.sm),
                          child: _VariantRow(variant: variant),
                        );
                      }).toList(),
                    );
                  },
                ),
                KSpacing.vGapXl,
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final Map<String, dynamic> group;
  const _GroupHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    final name = group['name']?.toString() ?? '';
    final desc = group['description']?.toString();
    final skuPrefix = group['skuPrefix']?.toString();
    final hsn = group['hsnCode']?.toString();
    final gst = (group['gstRate'] as num?)?.toDouble();
    final uom = group['defaultUom']?.toString();
    final purchase = (group['defaultPurchasePrice'] as num?)?.toDouble();
    final sale = (group['defaultSalePrice'] as num?)?.toDouble();
    final variantCount = (group['variantCount'] as num?)?.toInt() ?? 0;

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: KColors.primaryLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.category_outlined,
                    color: KColors.primary),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: KTypography.h2),
                    if (skuPrefix != null && skuPrefix.isNotEmpty)
                      Text('SKU prefix: $skuPrefix',
                          style: KTypography.bodySmall),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: KColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$variantCount variants',
                  style: KTypography.labelSmall.copyWith(
                    color: KColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (desc != null && desc.isNotEmpty) ...[
            KSpacing.vGapSm,
            Text(desc, style: KTypography.bodyMedium),
          ],
          KSpacing.vGapMd,
          const Divider(height: 1),
          KSpacing.vGapMd,
          Wrap(
            spacing: KSpacing.md,
            runSpacing: KSpacing.sm,
            children: [
              if (hsn != null && hsn.isNotEmpty)
                _MetaChip(label: 'HSN', value: hsn),
              if (gst != null) _MetaChip(label: 'GST', value: '${gst.toStringAsFixed(0)}%'),
              if (uom != null && uom.isNotEmpty)
                _MetaChip(label: 'UoM', value: uom),
              if (purchase != null)
                _MetaChip(
                    label: 'Purchase',
                    value: CurrencyFormatter.formatIndian(purchase)),
              if (sale != null)
                _MetaChip(
                    label: 'Sale',
                    value: CurrencyFormatter.formatIndian(sale)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;
  const _MetaChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: KTypography.labelSmall),
        Text(value, style: KTypography.labelLarge),
      ],
    );
  }
}

class _AttributeDefinitionsCard extends StatelessWidget {
  final Map<String, dynamic> group;
  const _AttributeDefinitionsCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final defs = (group['attributeDefinitions'] as List?) ?? const [];
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Attribute Definitions', style: KTypography.h3),
          KSpacing.vGapSm,
          if (defs.isEmpty)
            Text('No attributes defined yet.', style: KTypography.bodySmall)
          else
            ...defs.map<Widget>((d) {
              final def = d as Map<String, dynamic>;
              final key = def['key']?.toString() ?? '';
              final values = (def['values'] as List?) ?? const [];
              return Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(key, style: KTypography.labelLarge),
                    KSpacing.vGapXs,
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: values.map<Widget>((v) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: KColors.primarySoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(v.toString(),
                              style: KTypography.labelSmall),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _VariantRow extends StatelessWidget {
  final Map<String, dynamic> variant;
  const _VariantRow({required this.variant});

  @override
  Widget build(BuildContext context) {
    final id = variant['id']?.toString();
    final sku = variant['sku']?.toString() ?? '';
    final name = variant['name']?.toString() ?? '';
    final salePrice = (variant['salePrice'] as num?)?.toDouble() ?? 0;
    final attrs = (variant['variantAttributes'] as Map?) ?? const {};

    return KCard(
      onTap: () {
        if (id != null) context.push('/items/$id');
      },
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: KColors.primaryLight.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                color: KColors.primary, size: 18),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: KTypography.labelLarge),
                KSpacing.vGapXs,
                Text('SKU: $sku', style: KTypography.bodySmall),
                if (attrs.isNotEmpty) ...[
                  KSpacing.vGapXs,
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: attrs.entries.map<Widget>((e) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: KColors.primarySoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${e.key}: ${e.value}',
                            style: KTypography.labelSmall),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          KSpacing.hGapSm,
          Text(CurrencyFormatter.formatIndian(salePrice),
              style: KTypography.amountSmall),
          const Icon(Icons.chevron_right, color: KColors.textHint),
        ],
      ),
    );
  }
}
