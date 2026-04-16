import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/pos_cart_state.dart';
import '../data/pos_providers.dart';
import 'widgets/pos_search_bar.dart';
import 'widgets/pos_item_search_result.dart';
import 'widgets/pos_cart_list.dart';
import 'widgets/pos_total_bar.dart';

/// Quick POS Screen — counter billing optimized for speed.
///
/// Layout:
/// ┌─────────────────────────────────┐
/// │ 🔍 Search items or scan barcode │ ← sticky top
/// ├─────────────────────────────────┤
/// │ [Search results / Cart]         │ ← scrollable body
/// ├─────────────────────────────────┤
/// │ Total    ₹150.00                │ ← sticky bottom
/// │ [Cash] [UPI] [Card]             │
/// └─────────────────────────────────┘
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String? _searchQuery;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = value.trim().isEmpty ? null : value.trim();
      });
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = null);
    _searchFocusNode.requestFocus();
  }

  void _addToCart(Map<String, dynamic> item) {
    ref.read(posCartProvider.notifier).addItem(CartItem(
          itemId: item['id'] as String?,
          name: item['name'] as String? ?? 'Item',
          sku: item['sku'] as String?,
          barcode: item['barcode'] as String?,
          rate: (item['rate'] as num?)?.toDouble() ?? 0,
          unit: item['unit'] as String?,
          taxGroupId: item['taxGroupId'] as String?,
          taxGroupName: item['taxGroupName'] as String?,
          hsnCode: item['hsnCode'] as String?,
          batchId: item['batchId'] as String?,
        ));

    // Clear search and refocus for next item
    _clearSearch();

    // Brief haptic feedback
    HapticFeedback.lightImpact();
  }

  void _onPaymentTap(String mode) {
    ref.read(posCartProvider.notifier).setPaymentMode(mode);
    // TODO: Day 2 — show payment confirmation sheet, then submit
  }

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(posSearchProvider(_searchQuery));
    final cart = ref.watch(posCartProvider);
    final isSearching = _searchQuery != null && _searchQuery!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick POS'),
        actions: [
          if (cart.items.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                ref.read(posCartProvider.notifier).clear();
              },
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Clear'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Sticky search bar
          PosSearchBar(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onClear: _clearSearch,
            focusNode: _searchFocusNode,
          ),

          // Scrollable body — search results or cart
          Expanded(
            child: isSearching
                ? _buildSearchResults(searchAsync)
                : _buildCartView(cart),
          ),

          // Sticky total bar
          PosTotalBar(
            onCashTap: () => _onPaymentTap('CASH'),
            onUpiTap: () => _onPaymentTap('UPI'),
            onCardTap: () => _onPaymentTap('CARD'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(AsyncValue<List<Map<String, dynamic>>> searchAsync) {
    return searchAsync.when(
      loading: () => const KShimmerList(),
      error: (err, _) => KErrorView(message: 'Search failed: $err'),
      data: (results) {
        if (results.isEmpty) {
          return const KEmptyState(
            icon: Icons.search_off,
            title: 'No items found',
            subtitle: 'Try a different search term',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: results.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
          itemBuilder: (context, index) {
            return PosItemSearchResult(
              item: results[index],
              onTap: () => _addToCart(results[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildCartView(PosCartState cart) {
    if (cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.point_of_sale,
                size: 64, color: Theme.of(context).colorScheme.outlineVariant),
            KSpacing.vGapMd,
            Text('Ready to sell',
                style: KTypography.h3.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            KSpacing.vGapSm,
            Text('Search items above to start',
                style: KTypography.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return const SingleChildScrollView(
      child: PosCartList(),
    );
  }
}
