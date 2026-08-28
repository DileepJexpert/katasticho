import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_error_view.dart';
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../data/partner_network_repository.dart';

class CatalogListScreen extends ConsumerStatefulWidget {
  const CatalogListScreen({super.key});

  @override
  ConsumerState<CatalogListScreen> createState() => _CatalogListScreenState();
}

class _CatalogListScreenState extends ConsumerState<CatalogListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(catalogProvider);
    final cs = Theme.of(context).colorScheme;

    return KKeyboardListWrapper(
      itemCount: () => catalogAsync.valueOrNull?.length ?? 0,
      onRefresh: () => ref.invalidate(catalogProvider),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Published B2B Catalog'),
          actions: [
            IconButton(
              tooltip: 'Refresh Catalog',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => ref.invalidate(catalogProvider),
            ),
          ],
        ),
        body: catalogAsync.when(
          loading: () => const KLoading(message: 'Loading published catalog products...'),
          error: (e, _) => Center(
            child: Padding(
              padding: KSpacing.pagePadding,
              child: KErrorView(
                message: ApiErrorParser.message(e),
                onRetry: () => ref.invalidate(catalogProvider),
              ),
            ),
          ),
          data: (items) {
            final filtered = items.where((item) {
              if (_searchQuery.isEmpty) return true;
              final name = (item['displayName'] ?? '').toString().toLowerCase();
              final sku = (item['publishedSku'] ?? '').toString().toLowerCase();
              final q = _searchQuery.toLowerCase();
              return name.contains(q) || sku.contains(q);
            }).toList();

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(catalogProvider),
              child: ListView(
                padding: KSpacing.pagePadding,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Published Network Catalog',
                        style: KTypography.h2.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Items exposed to your approved network buyers with wholesale PTR and MRP pricing.',
                        style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  KSpacing.vGapMd,
                  TextFormField(
                    decoration: InputDecoration(
                      hintText: 'Search published items by product name or SKU...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(KSpacing.radiusMd)),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  KSpacing.vGapMd,
                  if (filtered.isEmpty)
                    KEmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'No published catalog items found',
                      subtitle: _searchQuery.isNotEmpty
                          ? 'No products match "$_searchQuery".'
                          : 'Publish items from your item master to make them discoverable to trading partners.',
                    )
                  else
                    ...filtered.map((item) {
                      return _CatalogCard(
                        item: item,
                        onUnpublish: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final id = item['id']?.toString();
                          if (id == null) return;
                          try {
                            await ref.read(partnerNetworkRepositoryProvider).unpublishCatalogItem(id);
                            ref.invalidate(catalogProvider);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Item successfully unpublished from B2B network'),
                                backgroundColor: KColors.success,
                              ),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Failed: ${ApiErrorParser.message(e)}'),
                                backgroundColor: KColors.error,
                              ),
                            );
                          }
                        },
                      );
                    }),
                ],
              ),
            );
          },
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
    final cs = Theme.of(context).colorScheme;
    final name = item['displayName']?.toString() ?? 'Unnamed Product';
    final sku = item['publishedSku']?.toString();
    final mrp = (item['publishedMrp'] as num?)?.toDouble();
    final ptr = (item['publishedPtr'] as num?)?.toDouble();
    final availability = item['availabilityStatus']?.toString() ?? 'AVAILABLE';
    final isActive = item['isActive'] == true;

    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      padding: const EdgeInsets.all(KSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(KSpacing.radiusMd),
            ),
            child: Icon(Icons.inventory_2_outlined, color: cs.primary, size: 20),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    KStatusChip(status: isActive ? availability : 'INACTIVE'),
                  ],
                ),
                if (sku != null && sku.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'SKU: $sku',
                    style: KTypography.mono(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (mrp != null) ...[
                      Text(
                        'MRP: ',
                        style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                      ),
                      KMoney(mrp, style: KTypography.bodySmall),
                    ],
                    if (mrp != null && ptr != null) ...[
                      const SizedBox(width: 12),
                      Text('•', style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(width: 12),
                    ],
                    if (ptr != null) ...[
                      Text(
                        'PTR (Wholesale): ',
                        style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                      ),
                      KMoney(ptr, style: KTypography.titleSmall.copyWith(color: KColors.primary)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isActive)
            IconButton(
              icon: Icon(Icons.visibility_off_outlined, size: 20, color: cs.onSurfaceVariant),
              tooltip: 'Unpublish Item',
              onPressed: onUnpublish,
            ),
        ],
      ),
    );
  }
}
