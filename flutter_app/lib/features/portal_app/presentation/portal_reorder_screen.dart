import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';
import '../data/portal_reorder_models.dart';
import '../data/portal_session.dart';

class PortalReorderScreen extends ConsumerStatefulWidget {
  const PortalReorderScreen({super.key});

  @override
  ConsumerState<PortalReorderScreen> createState() => _PortalReorderScreenState();
}

class _PortalReorderScreenState extends ConsumerState<PortalReorderScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  String? _error;
  List<PortalCatalogItem> _catalog = [];
  List<PortalCatalogItem> _frequent = [];
  final Map<String, PortalCartItem> _cart = {};

  String _filter = 'ALL'; // ALL, IN_STOCK, SCHEME, PHARMA, FMCG
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(portalDioProvider);
      final query = _searchCtrl.text.trim();
      final results = await Future.wait([
        dio.get(
          ApiConfig.portalCatalog,
          queryParameters: {
            if (query.isNotEmpty) 'search': query,
            'size': 100,
          },
        ),
        dio.get(ApiConfig.portalFrequentItems),
      ]);

      if (!mounted) return;

      final catalogData = results[0].data['data'] as Map<String, dynamic>?;
      final rawItems = (catalogData?['items'] as List?) ?? [];
      final parsedCatalog = rawItems
          .map((e) => PortalCatalogItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();

      final rawFrequent = (results[1].data['data'] as List?) ?? [];
      final parsedFrequent = rawFrequent
          .map((e) => PortalCatalogItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();

      setState(() {
        _catalog = parsedCatalog;
        _frequent = parsedFrequent;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _extractError(e);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load distributor catalog.';
        _loading = false;
      });
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Network error connecting to distributor catalog.';
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _loadData();
    });
  }

  void _updateQuantity(PortalCatalogItem item, double delta) {
    setState(() {
      final current = _cart[item.id]?.quantity ?? 0.0;
      final newQty = current + delta;
      if (newQty <= 0) {
        _cart.remove(item.id);
      } else {
        _cart[item.id] = PortalCartItem(item: item, quantity: newQty);
      }
    });
  }

  double get _cartTotal => _cart.values.fold(0.0, (acc, e) => acc + e.lineTotal);
  double get _cartSavings => _cart.values.fold(0.0, (acc, e) => acc + e.mrpSavings);
  int get _cartItemCount => _cart.values.fold(0, (acc, e) => acc + e.quantity.toInt());

  List<PortalCatalogItem> get _filteredCatalog {
    return _catalog.where((item) {
      if (_filter == 'IN_STOCK' && !item.inStock) return false;
      if (_filter == 'SCHEME' && (item.schemeDescription == null || item.schemeDescription!.isEmpty)) return false;
      if (_filter == 'PHARMA' && (item.composition == null || item.composition!.isEmpty)) return false;
      if (_filter == 'FMCG' && (item.category?.toLowerCase() != 'fmcg' && (item.composition != null && item.composition!.isNotEmpty))) return false;
      return true;
    }).toList();
  }

  void _openCheckoutSheet() {
    if (_cart.isEmpty) return;

    final notesCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: KSpacing.lg,
                right: KSpacing.lg,
                top: KSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Review & Place Order', style: KTypography.h2),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: KSpacing.md),
                    Text('${_cart.length} unique items ($cartItemCountCount units)',
                        style: KTypography.caption.copyWith(color: KColors.textSecondary)),
                    const SizedBox(height: KSpacing.md),
                    const Divider(height: 1),
                    const SizedBox(height: KSpacing.sm),
                    ..._cart.values.map((cartItem) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cartItem.item.name, style: KTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                                  Text(
                                    '${cartItem.quantity.toInt()} ${cartItem.item.unitOfMeasure} @ ₹${cartItem.unitEffectiveRate.toStringAsFixed(2)}',
                                    style: KTypography.caption.copyWith(color: KColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            KMoney(cartItem.lineTotal),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: KSpacing.md),
                    const Divider(height: 1),
                    const SizedBox(height: KSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Payable (incl. GST)', style: KTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                        KMoney(
                          _cartTotal,
                          style: KTypography.h2.copyWith(color: KColors.primary),
                        ),
                      ],
                    ),
                    if (_cartSavings > 0) ...[
                      const SizedBox(height: KSpacing.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Trade Savings', style: KTypography.caption.copyWith(color: KColors.success)),
                          Text('₹${_cartSavings.toStringAsFixed(2)}',
                              style: KTypography.caption.copyWith(color: KColors.success, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                    const SizedBox(height: KSpacing.lg),
                    KTextField(
                      label: 'Order Notes / Delivery Time',
                      hint: 'e.g. Please deliver before 4 PM or with evening route',
                      controller: notesCtrl,
                      maxLines: 2,
                    ),
                    const SizedBox(height: KSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: KButton(
                        label: _submitting ? 'Placing Order...' : 'Confirm & Send to Distributor',
                        icon: Icons.check_circle_outline,
                        variant: KButtonVariant.primary,
                        onPressed: _submitting
                            ? null
                            : () async {
                                setSheetState(() => _submitting = true);
                                final navigator = Navigator.of(context);
                                await _submitOrder(notesCtrl.text.trim());
                                setSheetState(() => _submitting = false);
                                if (mounted) navigator.pop();
                              },
                      ),
                    ),
                    const SizedBox(height: KSpacing.xl),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  int get cartItemCountCount => _cartItemCount;

  Future<void> _submitOrder(String notes) async {
    try {
      final dio = ref.read(portalDioProvider);
      final linesPayload = _cart.values.map((e) {
        return {
          'itemId': e.item.id,
          'quantity': e.quantity,
          'unit': e.item.unitOfMeasure,
        };
      }).toList();

      final res = await dio.post(
        ApiConfig.portalOrders,
        data: {
          'notes': notes,
          'lines': linesPayload,
        },
      );

      final orderData = res.data['data'] as Map<String, dynamic>?;
      final orderNumber = orderData?['salesorderNumber'] ?? 'Order';

      if (!mounted) return;
      setState(() {
        _cart.clear();
      });

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: KColors.success, size: 48),
          title: const Text('Order Placed Successfully!'),
          content: Text(
            'Your order ($orderNumber) has been confirmed and routed to the distributor dispatch queue.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Continue Reordering'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/portal/home');
              },
              child: const Text('View All Orders'),
            ),
          ],
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_extractError(e)),
          backgroundColor: KColors.error,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit order. Please try again.'),
          backgroundColor: KColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColors.bgApp,
      appBar: AppBar(
        title: const Text('Quick Reorder Catalog'),
        actions: [
          IconButton(
            tooltip: 'Refresh Catalog',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadData,
          ),
          if (_cart.isNotEmpty)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  tooltip: 'View Cart',
                  icon: const Icon(Icons.shopping_cart_outlined),
                  onPressed: _openCheckoutSheet,
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: KColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_cart.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: KEmptyState(
                          icon: Icons.error_outline,
                          title: 'Unable to load catalog',
                          subtitle: _error!,
                          actionLabel: 'Retry',
                          onAction: _loadData,
                        ),
                      )
                    : _buildContent(),
          ),
        ],
      ),
      bottomNavigationBar: _cart.isNotEmpty ? _buildStickyCartBar() : null,
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(KSpacing.md, KSpacing.sm, KSpacing.md, KSpacing.sm),
      child: Column(
        children: [
          KTextField(
            label: 'Search Items',
            hint: 'Search brand, generic salt, composition, barcode...',
            controller: _searchCtrl,
            prefixIcon: Icons.search,
            onChanged: _onSearchChanged,
            suffix: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      _loadData();
                    },
                  )
                : null,
          ),
          const SizedBox(height: KSpacing.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('ALL', 'All Items'),
                _filterChip('IN_STOCK', 'In Stock Only'),
                _filterChip('SCHEME', '⚡ Active Schemes'),
                _filterChip('PHARMA', '💊 Medicines / Salts'),
                _filterChip('FMCG', '🛒 FMCG & Goods'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final isSelected = _filter == key;
    return Padding(
      padding: const EdgeInsets.only(right: KSpacing.xs),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: KColors.primary.withValues(alpha: 0.15),
        labelStyle: TextStyle(
          color: isSelected ? KColors.primary : KColors.textSecondary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (val) {
          if (val) setState(() => _filter = key);
        },
      ),
    );
  }

  Widget _buildContent() {
    final items = _filteredCatalog;

    if (items.isEmpty && _frequent.isEmpty) {
      return const Center(
        child: KEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'No products found',
          subtitle: 'Try adjusting your search query or category filters.',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(KSpacing.md),
      children: [
        if (_frequent.isNotEmpty && _searchCtrl.text.isEmpty && _filter == 'ALL') ...[
          Text('⚡ 1-Tap Past Reorders', style: KTypography.h3),
          const SizedBox(height: KSpacing.xs),
          Text('Frequently purchased items for rapid 1-click carting',
              style: KTypography.caption.copyWith(color: KColors.textSecondary)),
          const SizedBox(height: KSpacing.sm),
          _buildFrequentStrip(),
          const SizedBox(height: KSpacing.lg),
          Text('All Distributor Inventory (${items.length})', style: KTypography.h3),
          const SizedBox(height: KSpacing.sm),
        ],
        ...items.map(_buildCatalogItemCard),
      ],
    );
  }

  Widget _buildFrequentStrip() {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _frequent.length,
        separatorBuilder: (_, __) => const SizedBox(width: KSpacing.sm),
        itemBuilder: (ctx, idx) {
          final item = _frequent[idx];
          final inCart = _cart[item.id];
          return Container(
            width: 200,
            padding: const EdgeInsets.all(KSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: KColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
                    if (item.brand != null)
                      Text(item.brand!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KTypography.caption.copyWith(color: KColors.textSecondary, fontSize: 11)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        KMoney(
                          item.salePrice,
                          size: KMoneySize.small,
                          style: TextStyle(fontWeight: FontWeight.bold, color: KColors.primary),
                        ),
                        if (item.mrp > item.salePrice)
                          KMoney(
                            item.mrp,
                            size: KMoneySize.small,
                            style: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: KColors.textHint,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                    inCart != null
                        ? Container(
                            decoration: BoxDecoration(
                              color: KColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => _updateQuantity(item, -1),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Icon(Icons.remove, size: 14),
                                  ),
                                ),
                                Text('${inCart.quantity.toInt()}',
                                    style: KTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
                                InkWell(
                                  onTap: () => _updateQuantity(item, 1),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Icon(Icons.add, size: 14),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => _updateQuantity(item, 1),
                            child: const Text('+ Add', style: TextStyle(fontSize: 11)),
                          ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCatalogItemCard(PortalCatalogItem item) {
    final cartItem = _cart[item.id];
    final qty = cartItem?.quantity ?? 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: KCard(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(item.name,
                                style: KTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 15)),
                          ),
                          const SizedBox(width: KSpacing.xs),
                          KStatusChip(
                            status: item.inStock ? 'IN_STOCK' : 'ON_ORDER',
                            label: item.inStock ? 'In Stock' : 'On Order',
                            dense: true,
                          ),
                        ],
                      ),
                      if (item.composition != null && item.composition!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Composition: ${item.composition!}',
                            style: KTypography.caption.copyWith(color: KColors.textSecondary, fontSize: 11)),
                      ],
                      if (item.brand != null || item.packSize != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (item.brand != null) 'Brand: ${item.brand}',
                            if (item.packSize != null) 'Pack: ${item.packSize}',
                            'Unit: ${item.unitOfMeasure}',
                          ].join('  •  '),
                          style: KTypography.caption.copyWith(color: KColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    KMoney(
                      item.salePrice,
                      size: KMoneySize.medium,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: KColors.primary),
                    ),
                    if (item.mrp > item.salePrice)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('MRP ', style: KTypography.caption.copyWith(color: KColors.textHint, fontSize: 10)),
                          KMoney(
                            item.mrp,
                            size: KMoneySize.small,
                            style: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: KColors.textHint,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
            if (item.schemeDescription != null && item.schemeDescription!.isNotEmpty) ...[
              const SizedBox(height: KSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: KColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_offer_outlined, size: 13, color: KColors.success),
                    const SizedBox(width: 4),
                    Text(
                      'Scheme: ${item.schemeDescription!}',
                      style: const TextStyle(
                        color: KColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: KSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: KSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.gstRate > 0 ? '+${item.gstRate.toInt()}% GST' : 'GST Exempt',
                  style: KTypography.caption.copyWith(color: KColors.textSecondary),
                ),
                qty > 0
                    ? Container(
                        decoration: BoxDecoration(
                          color: KColors.bgApp,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: KColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16),
                              onPressed: () => _updateQuantity(item, -1),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${qty.toInt()} ${item.unitOfMeasure}',
                                style: KTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 16),
                              onPressed: () => _updateQuantity(item, 1),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      )
                    : KButton(
                        label: 'Add to Order',
                        icon: Icons.add_shopping_cart,
                        size: KButtonSize.small,
                        variant: KButtonVariant.outlined,
                        onPressed: () => _updateQuantity(item, 1),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyCartBar() {
    return Container(
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${_cart.length} items ($cartItemCountCount units)',
                        style: KTypography.caption.copyWith(color: KColors.textSecondary),
                      ),
                      if (_cartSavings > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Save ₹${_cartSavings.toStringAsFixed(0)}',
                          style: KTypography.caption.copyWith(
                            color: KColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                  KMoney(
                    _cartTotal,
                    style: KTypography.h2.copyWith(color: KColors.primary),
                  ),
                ],
              ),
            ),
            KButton(
              label: 'Place Order',
              icon: Icons.arrow_forward,
              variant: KButtonVariant.primary,
              onPressed: _openCheckoutSheet,
            ),
          ],
        ),
      ),
    );
  }
}
