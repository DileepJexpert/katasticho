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
import 'widgets/pos_customer_button.dart';

/// Quick POS Screen — counter billing optimized for speed.
///
/// Layout:
/// ┌─────────────────────────────────┐
/// │ Quick POS            [Walk-in ▼]│ ← AppBar + customer chip
/// ├─────────────────────────────────┤
/// │ 🔍 Search items or scan barcode │ ← sticky top
/// ├─────────────────────────────────┤
/// │ [Search results / Cart]         │ ← scrollable body
/// ├─────────────────────────────────┤
/// │ Subtotal     ₹127.12           │
/// │ GST           ₹22.88           │
/// │ ──────────────────────         │
/// │ Total        ₹150.00           │
/// │ [Cash F1] [UPI F2] [Card F3]   │ ← sticky bottom
/// └─────────────────────────────────┘
///
/// Shortcuts:
///   Ctrl+F  → focus search
///   Enter   → add first search result
///   Ctrl+Enter → complete sale (Day 3)
///   Ctrl+Delete → clear cart
///   F1/F2/F3 → Cash/UPI/Card
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

  // ── Search ───────────────────────────────────────────────────

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
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

  /// Enter key in search — add the first result immediately.
  void _onSearchSubmitted(String value) {
    if (value.trim().isEmpty) return;
    final searchAsync = ref.read(posSearchProvider(_searchQuery));
    searchAsync.whenData((results) {
      if (results.isNotEmpty) {
        _addToCart(results.first);
      }
    });
  }

  // ── Cart operations ──────────────────────────────────────────

  void _addToCart(Map<String, dynamic> item) {
    final stock = (item['currentStock'] as num?)?.toDouble() ?? 0;
    if (stock <= 0) return; // Don't add out-of-stock items

    // Parse tax rate from taxGroupName (e.g. "GST 18%") or default 0
    final taxRate = _parseTaxRate(item['taxGroupName'] as String?);

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
          taxRate: taxRate,
          batchExpiry: item['batchExpiryDate'] as String?,
          currentStock: stock,
        ));

    // Clear search and refocus for next item
    _clearSearch();

    // Brief haptic feedback
    HapticFeedback.lightImpact();
  }

  double _parseTaxRate(String? taxGroupName) {
    if (taxGroupName == null || taxGroupName.isEmpty) return 0;
    // Match patterns like "GST 18%", "GST 5%", "18%"
    final match = RegExp(r'(\d+(?:\.\d+)?)%').firstMatch(taxGroupName);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  void _onPaymentTap(String mode) {
    ref.read(posCartProvider.notifier).setPaymentMode(mode);
    // TODO: Day 3 — show payment confirmation sheet, then submit
  }

  // ── Keyboard shortcuts ───────────────────────────────────────

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isCtrl = HardwareKeyboard.instance.isControlPressed;

    // Ctrl+F → focus search
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyF) {
      _searchFocusNode.requestFocus();
      return KeyEventResult.handled;
    }

    // Ctrl+Delete → clear cart
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.delete) {
      ref.read(posCartProvider.notifier).clear();
      _searchFocusNode.requestFocus();
      return KeyEventResult.handled;
    }

    // F1 → Cash
    if (event.logicalKey == LogicalKeyboardKey.f1) {
      _onPaymentTap('CASH');
      return KeyEventResult.handled;
    }

    // F2 → UPI
    if (event.logicalKey == LogicalKeyboardKey.f2) {
      _onPaymentTap('UPI');
      return KeyEventResult.handled;
    }

    // F3 → Card
    if (event.logicalKey == LogicalKeyboardKey.f3) {
      _onPaymentTap('CARD');
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(posSearchProvider(_searchQuery));
    final cart = ref.watch(posCartProvider);
    final isSearching = _searchQuery != null && _searchQuery!.isNotEmpty;

    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quick POS'),
          actions: [
            const PosCustomerButton(),
            const SizedBox(width: 8),
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
              onSubmitted: _onSearchSubmitted,
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
      ),
    );
  }

  Widget _buildSearchResults(
      AsyncValue<List<Map<String, dynamic>>> searchAsync) {
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
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 72),
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
                size: 64,
                color: Theme.of(context).colorScheme.outlineVariant),
            KSpacing.vGapMd,
            Text('Ready to sell',
                style: KTypography.h3.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant)),
            KSpacing.vGapSm,
            Text('Search items above to start',
                style: KTypography.bodySmall.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant)),
            KSpacing.vGapMd,
            Text('Ctrl+F to focus search',
                style: KTypography.labelSmall.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant)),
          ],
        ),
      );
    }

    return const SingleChildScrollView(
      child: PosCartList(),
    );
  }
}
