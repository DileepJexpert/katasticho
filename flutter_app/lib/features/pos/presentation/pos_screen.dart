import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/pos_cart_state.dart';
import '../data/pos_held_carts.dart';
import '../data/pos_recent_transactions.dart';
import '../data/pos_providers.dart';
import '../data/pos_repository.dart';
import 'widgets/pos_search_bar.dart';
import 'widgets/pos_item_search_result.dart';
import 'widgets/pos_cart_list.dart';
import 'widgets/pos_total_bar.dart';
import 'widgets/pos_customer_button.dart';
import 'widgets/pos_payment_sheet.dart';
import 'widgets/pos_success_sheet.dart';
import 'widgets/pos_held_carts_sheet.dart';
import 'widgets/pos_favourites_grid.dart';
import 'widgets/pos_barcode_scanner.dart';
import 'widgets/pos_recent_transactions.dart';
import 'widgets/pos_weight_popup.dart';

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
  bool _isSubmitting = false;

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

  void _addToCart(Map<String, dynamic> item) async {
    final stock = (item['currentStock'] as num?)?.toDouble() ?? 0;
    if (stock <= 0) return;

    final batchExpiry = item['batchExpiryDate'] as String?;
    if (batchExpiry != null && batchExpiry.isNotEmpty) {
      final expiry = DateTime.tryParse(batchExpiry);
      if (expiry != null && expiry.isBefore(DateTime.now())) {
        _showErrorSnackBar('Batch expired ($batchExpiry) — sale blocked');
        return;
      }
    }

    final taxRate = _parseTaxRate(item['taxGroupName'] as String?);
    final isWeightBased = item['weightBasedBilling'] == true;
    final rate = (item['rate'] as num?)?.toDouble() ?? 0;
    final itemName = item['name'] as String? ?? 'Item';

    double quantity = 1;
    String? unit = item['unit'] as String?;

    if (isWeightBased) {
      final weightKg = await showWeightPopup(
        context,
        itemName: itemName,
        ratePerKg: rate,
      );
      if (weightKg == null || !mounted) return;
      quantity = weightKg;
      unit = 'KG';
    }

    ref.read(posCartProvider.notifier).addItem(CartItem(
          itemId: item['id'] as String?,
          name: itemName,
          sku: item['sku'] as String?,
          barcode: item['barcode'] as String?,
          rate: rate,
          unit: unit,
          taxGroupId: item['taxGroupId'] as String?,
          taxGroupName: item['taxGroupName'] as String?,
          hsnCode: item['hsnCode'] as String?,
          batchId: item['batchId'] as String?,
          batchNumber: item['batchNumber'] as String?,
          taxRate: taxRate,
          batchExpiry: batchExpiry,
          currentStock: stock,
          isWeightBased: isWeightBased,
          quantity: quantity,
        ));

    _clearSearch();
    HapticFeedback.lightImpact();
  }

  double _parseTaxRate(String? taxGroupName) {
    if (taxGroupName == null || taxGroupName.isEmpty) return 0;
    final match = RegExp(r'(\d+(?:\.\d+)?)%').firstMatch(taxGroupName);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  // ── Hold / Recall ────────────────────────────────────────────

  void _holdCart() {
    final cart = ref.read(posCartProvider);
    if (cart.isEmpty) return;
    final notifier = ref.read(heldCartsProvider.notifier);
    if (!notifier.canHold) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 held carts reached')),
      );
      return;
    }
    notifier.hold(cart);
    ref.read(posCartProvider.notifier).clear();
    _searchFocusNode.requestFocus();
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cart held')),
    );
  }

  Future<void> _recallCart() async {
    final recalled = await showHeldCartsSheet(context);
    if (recalled == null || !mounted) return;
    final currentCart = ref.read(posCartProvider);
    if (!currentCart.isEmpty) {
      ref.read(heldCartsProvider.notifier).hold(currentCart, label: 'Auto-held');
    }
    ref.read(posCartProvider.notifier).restore(recalled);
    HapticFeedback.lightImpact();
  }

  // ── Barcode / Recent ─────────────────────────────────────────

  Future<void> _scanBarcode() async {
    final code = await showBarcodeScanner(context);
    if (code == null || !mounted) return;
    _searchController.text = code;
    _onSearchChanged(code);
    _onSearchSubmitted(code);
  }

  Future<void> _showRecentTransactions() async {
    final result = await showRecentTransactionsSheet(context);
    if (result == null || !mounted) return;
    final receiptId = result['receiptId'] as String;
    final action = result['action'] as String;
    final repo = ref.read(posRepositoryProvider);
    if (action == 'print') {
      await _handlePrint(repo, receiptId);
    } else if (action == 'whatsapp') {
      try {
        final receipt = await repo.getReceipt(receiptId);
        final data = (receipt['data'] ?? receipt) as Map<String, dynamic>;
        final cart = ref.read(posCartProvider);
        await _handleWhatsApp(repo, receiptId, data, cart);
      } catch (e) {
        if (mounted) _showErrorSnackBar('Failed: $e');
      }
    }
  }

  // ── Payment flow ─────────────────────────────────────────────

  Future<void> _onPaymentTap(String mode) async {
    final cart = ref.read(posCartProvider);
    if (cart.isEmpty) return;

    ref.read(posCartProvider.notifier).setPaymentMode(mode);

    final paymentResult = await showPosPaymentSheet(
      context,
      cart: cart,
      paymentMode: mode,
    );

    if (paymentResult == null || !mounted) return;

    await _completeSale(paymentResult);
  }

  Future<void> _completeSale(Map<String, dynamic> paymentResult) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final cart = ref.read(posCartProvider);
    final repo = ref.read(posRepositoryProvider);

    try {
      // Build receipt request matching CreateSalesReceiptRequest
      final requestBody = _buildReceiptRequest(cart, paymentResult);
      final response = await repo.createReceipt(requestBody);

      if (!mounted) return;

      HapticFeedback.mediumImpact();

      // Show success sheet
      final action = await showPosSuccessSheet(
        context,
        receipt: response,
        customerPhone: cart.contactPhone,
      );

      // Extract receipt ID for actions
      final receiptData = response['data'] is Map
          ? response['data'] as Map<String, dynamic>
          : response;
      final receiptId = receiptData['id']?.toString();

      if (mounted && receiptId != null) {
        await _handleSuccessAction(action, receiptId, receiptData, cart);
      }

      // Track in recent transactions
      if (receiptId != null) {
        ref.read(recentTransactionsProvider.notifier).add(
              RecentTransaction(
                receiptId: receiptId,
                receiptNumber:
                    receiptData['receiptNumber']?.toString() ?? '',
                total:
                    (receiptData['total'] as num?)?.toDouble() ?? 0,
                paymentMode:
                    receiptData['paymentMode']?.toString() ?? 'CASH',
                customerName: cart.contactName,
                completedAt: DateTime.now(),
              ),
            );
      }

      // Clear cart and refocus for next sale
      ref.read(posCartProvider.notifier).clear();
      _searchFocusNode.requestFocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sale failed: $e'),
          backgroundColor: KColors.error,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _completeSale(paymentResult),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Map<String, dynamic> _buildReceiptRequest(
      PosCartState cart, Map<String, dynamic> paymentResult) {
    final now = DateTime.now();
    return {
      if (cart.contactId != null) 'contactId': cart.contactId,
      'receiptDate': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      'paymentMode': paymentResult['paymentMode'],
      'amountReceived': paymentResult['amountReceived'],
      if (paymentResult['upiReference'] != null)
        'upiReference': paymentResult['upiReference'],
      if (cart.notes != null) 'notes': cart.notes,
      'lines': cart.items
          .map((item) => {
                if (item.itemId != null) 'itemId': item.itemId,
                'description': item.name,
                'quantity': item.quantity,
                if (item.unit != null) 'unit': item.unit,
                'rate': item.rate,
                if (item.taxGroupId != null) 'taxGroupId': item.taxGroupId,
                if (item.hsnCode != null) 'hsnCode': item.hsnCode,
                if (item.batchId != null) 'batchId': item.batchId,
                if (item.isWeightBased) 'weightBased': true,
              })
          .toList(),
    };
  }

  Future<void> _handleSuccessAction(
    SuccessAction? action,
    String receiptId,
    Map<String, dynamic> receiptData,
    PosCartState cart,
  ) async {
    if (action == null || action == SuccessAction.skip) return;

    final repo = ref.read(posRepositoryProvider);

    switch (action) {
      case SuccessAction.print:
        await _handlePrint(repo, receiptId);
        break;
      case SuccessAction.whatsapp:
        await _handleWhatsApp(repo, receiptId, receiptData, cart);
        break;
      case SuccessAction.email:
        _showInfoSnackBar('Email receipt coming soon');
        break;
      case SuccessAction.skip:
        break;
    }
  }

  Future<void> _handlePrint(PosRepository repo, String receiptId) async {
    try {
      _showInfoSnackBar('Generating receipt...');
      final pdfBytes = await repo.printReceipt(receiptId);
      if (!mounted) return;
      // Use the printing package to send to printer
      _showInfoSnackBar('Receipt ready (${pdfBytes.length} bytes)');
    } catch (e) {
      if (mounted) _showErrorSnackBar('Print failed: $e');
    }
  }

  Future<void> _handleWhatsApp(
    PosRepository repo,
    String receiptId,
    Map<String, dynamic> receiptData,
    PosCartState cart,
  ) async {
    try {
      final linkResponse = await repo.getWhatsAppLink(receiptId);
      final linkData = linkResponse['data'] is Map
          ? linkResponse['data'] as Map<String, dynamic>
          : linkResponse;
      final shareUrl = linkData['shareUrl']?.toString() ?? '';

      final receiptNumber =
          receiptData['receiptNumber']?.toString() ?? '';
      final total = (receiptData['total'] as num?)?.toDouble() ?? 0;
      final paymentMode =
          receiptData['paymentMode']?.toString() ?? 'CASH';

      final message = 'Receipt from your store\n\n'
          'Receipt: $receiptNumber\n'
          'Total: ${_formatAmount(total)}\n'
          'Paid via $paymentMode\n\n'
          'View full receipt: $shareUrl\n\n'
          '— Sent via Katasticho';

      String? phone = cart.contactPhone;
      if (phone == null || phone.isEmpty) {
        phone = await _promptForPhone();
      }
      if (phone == null || phone.isEmpty) return;

      // Clean phone number — remove spaces, dashes, leading +
      phone = phone.replaceAll(RegExp(r'[\s\-\+]'), '');
      if (phone.length == 10) phone = '91$phone'; // default India

      final waUrl = Uri.parse(
          'https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
      if (await canLaunchUrl(waUrl)) {
        await launchUrl(waUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('WhatsApp share failed: $e');
    }
  }

  Future<String?> _promptForPhone() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Customer Phone'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter phone number',
            prefixText: '+91 ',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    return '\u20B9${amount.toStringAsFixed(2)}';
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: KColors.error,
      ),
    );
  }

  // ── Keyboard shortcuts ───────────────────────────────────────

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isCtrl = HardwareKeyboard.instance.isControlPressed;

    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyF) {
      _searchFocusNode.requestFocus();
      return KeyEventResult.handled;
    }

    // Ctrl+Enter → complete sale with current payment mode
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.enter) {
      final cart = ref.read(posCartProvider);
      if (!cart.isEmpty) _onPaymentTap(cart.paymentMode);
      return KeyEventResult.handled;
    }

    if (isCtrl && event.logicalKey == LogicalKeyboardKey.delete) {
      ref.read(posCartProvider.notifier).clear();
      _searchFocusNode.requestFocus();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.f1) {
      _onPaymentTap('CASH');
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.f2) {
      _onPaymentTap('UPI');
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.f3) {
      _onPaymentTap('CARD');
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.f4) {
      _holdCart();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.f5) {
      _recallCart();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.f6) {
      final cart = ref.read(posCartProvider);
      if (!cart.isEmpty) _onPaymentTap('SPLIT');
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.f7) {
      _scanBarcode();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_searchQuery != null) {
        _clearSearch();
        return KeyEventResult.handled;
      }
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
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: const Text('Quick POS'),
              actions: [
                const PosCustomerButton(),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _scanBarcode,
                  icon: const Icon(Icons.qr_code_scanner, size: 20),
                  tooltip: 'Scan barcode (F7)',
                ),
                IconButton(
                  onPressed: _showRecentTransactions,
                  icon: const Icon(Icons.receipt_long, size: 20),
                  tooltip: 'Recent sales',
                ),
                if (cart.items.isNotEmpty)
                  IconButton(
                    onPressed: _holdCart,
                    icon: const Icon(Icons.pause_circle_outline, size: 20),
                    tooltip: 'Hold cart (F4)',
                  ),
                _HeldCartsBadge(onTap: _recallCart),
                if (cart.items.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      ref.read(posCartProvider.notifier).clear();
                    },
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear'),
                  ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  onPressed: () => context.push('/pos/receipt-settings'),
                  tooltip: 'Receipt settings',
                ),
                const SizedBox(width: 4),
              ],
            ),
            body: Column(
              children: [
                PosSearchBar(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onClear: _clearSearch,
                  onSubmitted: _onSearchSubmitted,
                  focusNode: _searchFocusNode,
                ),
                Expanded(
                  child: isSearching
                      ? _buildSearchResults(searchAsync)
                      : _buildCartView(cart),
                ),
                PosTotalBar(
                  onCashTap: () => _onPaymentTap('CASH'),
                  onUpiTap: () => _onPaymentTap('UPI'),
                  onCardTap: () => _onPaymentTap('CARD'),
                  onSplitTap: () => _onPaymentTap('SPLIT'),
                ),
              ],
            ),
          ),

          // Loading overlay during sale submission
          if (_isSubmitting)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Processing sale...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
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
      return SingleChildScrollView(
        child: Column(
          children: [
            PosFavouritesGrid(onItemTap: _addToCart),
            KSpacing.vGapLg,
            Center(
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
                  Wrap(
                    spacing: 16,
                    children: [
                      Text('F1 Cash', style: _shortcutStyle),
                      Text('F2 UPI', style: _shortcutStyle),
                      Text('F3 Card', style: _shortcutStyle),
                      Text('F4 Hold', style: _shortcutStyle),
                      Text('F5 Recall', style: _shortcutStyle),
                      Text('F6 Split', style: _shortcutStyle),
                      Text('F7 Scan', style: _shortcutStyle),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const SingleChildScrollView(
      child: PosCartList(),
    );
  }

  TextStyle get _shortcutStyle => KTypography.labelSmall.copyWith(
      color: Theme.of(context).colorScheme.outlineVariant, fontSize: 10);
}

class _HeldCartsBadge extends ConsumerWidget {
  final VoidCallback onTap;
  const _HeldCartsBadge({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(heldCartsProvider).length;
    if (count == 0) return const SizedBox.shrink();

    return Badge(
      label: Text('$count'),
      child: IconButton(
        icon: const Icon(Icons.inventory_2_outlined, size: 20),
        onPressed: onTap,
        tooltip: 'Recall held cart (F5)',
      ),
    );
  }
}
