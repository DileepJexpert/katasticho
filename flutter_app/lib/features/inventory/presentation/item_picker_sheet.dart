import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/item_repository.dart';

/// Modal item picker. Returns the selected item map (with id, sku, name,
/// salePrice, gstRate, hsnCode, etc.) or null if cancelled.
Future<Map<String, dynamic>?> showItemPicker(BuildContext context) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => _ItemPickerSheet(
        scrollController: scrollController,
      ),
    ),
  );
}

class _ItemPickerSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  const _ItemPickerSheet({required this.scrollController});

  @override
  ConsumerState<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends ConsumerState<_ItemPickerSheet> {
  final _searchController = TextEditingController();
  String? _query;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemListProvider(_query));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(KSpacing.md, KSpacing.md, KSpacing.md, KSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Item', style: KTypography.h3),
                KSpacing.vGapSm,
                KTextField.search(
                  controller: _searchController,
                  hint: 'Search by SKU or name',
                  onChanged: (v) =>
                      setState(() => _query = v.trim().isEmpty ? null : v.trim()),
                  onClear: () {
                    _searchController.clear();
                    setState(() => _query = null);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: itemsAsync.when(
              loading: () => const KShimmerList(),
              error: (err, st) {
                debugPrint('[ItemPicker] ERROR: $err\n$st');
                return KErrorView(message: 'Failed to load items');
              },
              data: (data) {
                final content = data['data'];
                final items = content is List
                    ? content
                    : (content is Map ? (content['content'] as List?) ?? [] : []);

                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _query == null ? 'No items yet' : 'No matches',
                        style: KTypography.bodyMedium,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  controller: widget.scrollController,
                  padding: KSpacing.pagePadding,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index] as Map<String, dynamic>;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: KColors.primaryLight.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          (item['itemType'] == 'SERVICE')
                              ? Icons.build_outlined
                              : Icons.inventory_2_outlined,
                          color: KColors.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(item['name']?.toString() ?? '',
                          style: KTypography.labelLarge),
                      subtitle: Text(
                        'SKU: ${item['sku'] ?? ''}'
                        '${item['totalOnHand'] != null ? ' • ${item['totalOnHand']} on hand' : ''}',
                        style: KTypography.bodySmall,
                      ),
                      trailing: Text(
                        CurrencyFormatter.formatIndian(
                            (item['salePrice'] as num?)?.toDouble() ?? 0),
                        style: KTypography.amountSmall,
                      ),
                      onTap: () => Navigator.pop(context, item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
