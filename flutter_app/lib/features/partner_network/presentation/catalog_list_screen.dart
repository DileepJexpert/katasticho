import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/widgets/widgets.dart';
import '../data/partner_network_repository.dart';

class CatalogListScreen extends ConsumerWidget {
  const CatalogListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(catalogProvider);
    final theme = Theme.of(context);

    return KKeyboardListWrapper(
      itemCount: () => catalogAsync.valueOrNull?.length ?? 0,
      onRefresh: () => ref.invalidate(catalogProvider),
      child: Scaffold(
        body: Column(
          children: [
            const KListPageHeader(
              title: 'Published Catalog',
              subtitle: 'Items visible to your approved trading partners.',
            ),
            Expanded(
              child: catalogAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => KErrorView(message: e.toString(), onRetry: () => ref.invalidate(catalogProvider)),
                data: (items) {
                  if (items.isEmpty) {
                    return const KEmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'No published items',
                      subtitle: 'Publish items from your inventory to make them visible to trading partners.',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(catalogProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (ctx, i) => _CatalogCard(
                        item: items[i],
                        onUnpublish: () async {
                          final id = items[i]['id']?.toString();
                          if (id == null) return;
                          try {
                            await ref.read(partnerNetworkRepositoryProvider).unpublishCatalogItem(id);
                            ref.invalidate(catalogProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Item unpublished')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                            }
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.item, required this.onUnpublish});
  final Map<String, dynamic> item;
  final VoidCallback onUnpublish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = item['displayName']?.toString() ?? 'Unnamed';
    final sku = item['publishedSku']?.toString();
    final mrp = item['publishedMrp'];
    final ptr = item['publishedPtr'];
    final availability = item['availabilityStatus']?.toString() ?? 'AVAILABLE';
    final isActive = item['isActive'] == true;

    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      KStatusChip(label: isActive ? availability : 'INACTIVE'),
                    ],
                  ),
                  if (sku != null) ...[
                    const SizedBox(height: 2),
                    Text('SKU: $sku', style: theme.textTheme.bodySmall),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (mrp != null) Text('MRP: ₹$mrp', style: theme.textTheme.bodySmall),
                      if (mrp != null && ptr != null) const SizedBox(width: 12),
                      if (ptr != null) Text('PTR: ₹$ptr', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
            if (isActive)
              IconButton(
                icon: const Icon(Icons.visibility_off_outlined, size: 20),
                tooltip: 'Unpublish',
                onPressed: onUnpublish,
              ),
          ],
        ),
      ),
    );
  }
}
