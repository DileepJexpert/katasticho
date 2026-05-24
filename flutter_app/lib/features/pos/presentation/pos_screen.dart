import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/pos_cart_state.dart';
import '../data/pos_held_carts.dart';
import '../data/pos_recent_transactions.dart';
import '../data/pos_providers.dart';
import '../data/pos_repository.dart';
import '../data/sales_receipt_providers.dart';
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
import 'widgets/pos_recent_bills.dart';
import 'widgets/pos_weight_popup.dart';
import '../../inventory/data/batch_repository.dart';
import '../../inventory/presentation/batch_picker_sheet.dart';
import '../../pricing/data/scheme_repository.dart';
import '../../../core/auth/auth_state.dart';
import '../../loyalty/data/wallet_repository.dart';
import '../../loyalty/presentation/wallet_balance_chip.dart';
import '../../pharma/data/prescription_repository.dart';

bool _isBeforeToday(DateTime date) {
  final today = DateUtils.dateOnly(DateTime.now());
  return DateUtils.dateOnly(date).isBefore(today);
}

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
  bool _showRecentPanel = false;

  // Wallet redemption — amount chosen by cashier for the current sale.
  double _walletRedeemAmount = 0;
  String? _walletRedeemContactId; // matches the cart's contactId

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
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final q = value.trim();
      setState(() {
        _searchQuery = q.length < 2 ? null : q;
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

  void _addToCart(Map<String, dynamic> itemData) async {
    var item = itemData; // mutable local — may be overridden by batch picker
    final stock = (item['currentStock'] as num?)?.toDouble() ?? 0;
    if (stock <= 0) {
      _showErrorSnackBar('${item['name'] ?? 'Item'} is out of stock');
      return;
    }

    final batchExpiry = item['batchExpiryDate'] as String?;
    if (batchExpiry != null && batchExpiry.isNotEmpty) {
      final expiry = DateTime.tryParse(batchExpiry);
      if (expiry != null && _isBeforeToday(expiry)) {
        _showErrorSnackBar('Batch expired ($batchExpiry) — sale blocked');
        return;
      }
    }

    // For batch-tracked items, auto-select if single batch, else show picker
    final trackBatches = item['trackBatches'] == true;
    if (trackBatches) {
      final itemId = item['id']?.toString();
      final itemName = item['name']?.toString() ?? 'Item';
      if (itemId == null) return;
      final batchRepo = ref.read(batchRepositoryProvider);
      final batches = await batchRepo.availableForItem(itemId);
      if (!mounted) return;
      // Filter out expired batches
      final validBatches = batches.where((b) {
        final exp = b['expiryDate']?.toString();
        if (exp == null || exp.isEmpty) return true;
        final d = DateTime.tryParse(exp);
        return d == null || !_isBeforeToday(d);
      }).toList();
      if (validBatches.isEmpty) {
        _showErrorSnackBar('No valid batches available for $itemName');
        return;
      }
      Map<String, dynamic>? batch;
      if (validBatches.length == 1) {
        // Single valid batch — auto-select silently (FEFO)
        batch = validBatches.first;
      } else {
        // Multiple batches — show picker
        batch =
            await showBatchPicker(context, itemId: itemId, itemName: itemName);
        if (batch == null || !mounted) return;
      }
      // Override batch fields from selection
      item = Map<String, dynamic>.from(item);
      item['batchId'] = batch['id']?.toString();
      item['batchNumber'] = batch['batchNumber']?.toString();
      item['batchExpiryDate'] = batch['expiryDate']?.toString();
      final batchStock = (batch['quantityAvailable'] as num?)?.toDouble();
      if (batchStock != null) item['currentStock'] = batchStock;
    }

    final taxRate = _parseTaxRate(item['taxGroupName'] as String?);
    final isWeightBased = item['weightBasedBilling'] == true;
    final rate = (item['rate'] as num?)?.toDouble() ?? 0;
    final mrp = (item['mrp'] as num?)?.toDouble();
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

    // Secondary units for multi-unit selling
    final secUnits = (item['secondaryUnits'] as List?)
            ?.map((u) => u as Map<String, dynamic>)
            .toList() ??
        const <Map<String, dynamic>>[];

    // Re-read stock and expiry — may have been overridden by batch picker above
    final effectiveStock = (item['currentStock'] as num?)?.toDouble() ?? stock;
    final effectiveBatchExpiry = item['batchExpiryDate'] as String?;

    // Prescription check — pharmacy vertical only
    String? prescriptionNumber;
    final authState = ref.read(authProvider);
    final isPharmacy =
        (authState.industryCode ?? '').toUpperCase().contains('PHARMA') ||
            (authState.businessType ?? '').toUpperCase().contains('PHARMA');
    if (isPharmacy && item['prescriptionRequired'] == true) {
      prescriptionNumber = await _askPrescriptionNumber(itemName);
      if (!mounted) return;
      if (prescriptionNumber == null) return; // user cancelled
    }

    final cartItem = CartItem(
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
      batchExpiry: effectiveBatchExpiry,
      currentStock: effectiveStock,
      isWeightBased: isWeightBased,
      mrp: mrp,
      purchasePrice: (item['purchasePrice'] as num?)?.toDouble(),
      quantity: quantity,
      availableUnits: secUnits,
      discountThresholds: item['discountThresholds'] as Map<String, dynamic>?,
      prescriptionNumber: prescriptionNumber,
    );

    CartItem? existing;
    for (final current in ref.read(posCartProvider).items) {
      if (current.itemId != null && current.itemId == cartItem.itemId) {
        existing = current;
        break;
      }
    }
    if (existing != null &&
        existing.quantity + cartItem.quantity > existing.maxSellQuantity) {
      _showErrorSnackBar(
        'Only ${_fmtQty(existing.maxSellQuantity)} ${existing.stockUnitLabel} available for ${existing.name}',
      );
    }

    ref.read(posCartProvider.notifier).addItem(cartItem);

    // Scheme auto-apply — check applicable schemes for this item + quantity
    final itemIdForScheme = cartItem.itemId;
    if (itemIdForScheme != null) {
      _checkAndApplyScheme(itemIdForScheme, cartItem.quantity, cartItem);
    }

    _clearSearch();
    HapticFeedback.lightImpact();
  }

  Future<String?> _askPrescriptionNumber(String itemName) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.local_pharmacy_outlined,
              color: Color(0xFFB71C1C), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('Prescription Required', style: KTypography.h3)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$itemName requires a valid prescription.',
                style: KTypography.bodySmall
                    .copyWith(color: KColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Prescription No.',
                hintText: 'Enter Rx number',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
                ctx, ctrl.text.trim().isEmpty ? '—' : ctrl.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _checkAndApplyScheme(
      String itemId, double qty, CartItem addedItem) async {
    try {
      final schemes =
          await ref.read(schemeRepositoryProvider).getApplicable(itemId, qty);
      if (schemes.isEmpty || !mounted) return;
      // Auto-apply the best (first) scheme silently
      final best = schemes.first;
      _applyScheme(best, addedItem);
      final schemeName = best['name']?.toString() ?? 'Scheme';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$schemeName applied'),
          backgroundColor: KColors.success,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (_) {
      // Silently ignore scheme fetch errors — don't interrupt POS flow
    }
  }

  void _applyScheme(Map<String, dynamic> scheme, CartItem addedItem) {
    final type = scheme['schemeType']?.toString() ?? '';
    final schemeId = scheme['id']?.toString();
    final schemeName = scheme['name']?.toString() ?? '';
    final cart = ref.read(posCartProvider);
    final notifier = ref.read(posCartProvider.notifier);

    if (type == 'BUY_X_GET_Y') {
      final freeQty = (scheme['freeQuantity'] as num?)?.toDouble() ?? 1;
      // Add a free line for the same item
      final freeItem = CartItem(
        itemId: addedItem.itemId,
        name: '${addedItem.name} [FREE - $schemeName]',
        sku: addedItem.sku,
        rate: addedItem.rate,
        unit: addedItem.unit,
        taxGroupId: addedItem.taxGroupId,
        taxGroupName: addedItem.taxGroupName,
        taxRate: addedItem.taxRate,
        hsnCode: addedItem.hsnCode,
        quantity: freeQty,
        currentStock: addedItem.currentStock,
        isFreeItem: true,
        appliedSchemeId: schemeId,
        appliedSchemeName: schemeName,
      );
      notifier.addItem(freeItem);
    } else if (type == 'PERCENT_DISCOUNT') {
      // Apply discount to the matching cart line
      final discPct = (scheme['discountPercent'] as num?)?.toDouble() ?? 0;
      final idx = cart.items
          .indexWhere((i) => i.itemId == addedItem.itemId && !i.isFreeItem);
      if (idx >= 0) {
        final updated = List<CartItem>.from(cart.items);
        updated[idx] = updated[idx].copyWith(
          discountPct: discPct,
          appliedSchemeId: schemeId,
          appliedSchemeName: schemeName,
        );
        notifier.restore(cart.copyWith(items: updated));
      }
    }
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
      const SnackBar(
        content: Text('Cart held'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _recallCart() async {
    final recalled = await showHeldCartsSheet(context);
    if (recalled == null || !mounted) return;
    final currentCart = ref.read(posCartProvider);
    if (!currentCart.isEmpty) {
      ref
          .read(heldCartsProvider.notifier)
          .hold(currentCart, label: 'Auto-held');
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
    final isWide =
        MediaQuery.of(context).size.width >= KSpacing.desktopBreakpoint;
    if (isWide) {
      setState(() => _showRecentPanel = !_showRecentPanel);
      return;
    }
    final result = await showRecentTransactionsSheet(context);
    if (result != null && mounted) _handleRecentAction(result);
  }

  Future<void> _showCartDiscount() async {
    final cart = ref.read(posCartProvider);
    if (cart.items.isEmpty) return;

    final currentPct =
        cart.items.isNotEmpty ? cart.items.first.discountPct : 0.0;
    final controller = TextEditingController(
      text: currentPct > 0 ? currentPct.toStringAsFixed(1) : '',
    );

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cart Discount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apply % discount to all ${cart.items.length} items',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Discount %',
                suffixText: '%',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, 0.0);
            },
            child: const Text('Remove Discount'),
          ),
          FilledButton(
            onPressed: () {
              final pct = double.tryParse(controller.text.trim()) ?? 0;
              Navigator.pop(ctx, pct.clamp(0.0, 100.0));
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (result != null && mounted) {
      ref.read(posCartProvider.notifier).applyGlobalDiscount(result);
    }
  }

  Future<void> _showNotesDialog() async {
    final current = ref.read(posCartProvider).notes ?? '';
    final controller = TextEditingController(text: current);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Receipt Note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          maxLength: 200,
          decoration: const InputDecoration(
            hintText: 'e.g. Regular customer, special order…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          if (current.isNotEmpty)
            TextButton(
              onPressed: () {
                ref.read(posCartProvider.notifier).setNotes(null);
                Navigator.pop(ctx);
              },
              child: const Text('Clear'),
            ),
          FilledButton(
            onPressed: () {
              final note = controller.text.trim();
              ref
                  .read(posCartProvider.notifier)
                  .setNotes(note.isEmpty ? null : note);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  Future<void> _handleRecentAction(Map<String, String> result) async {
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

    if (cart.hasBlockedItems) {
      _showErrorSnackBar(
          'Cannot complete sale — one or more items are below cost. Adjust discount or remove the item.');
      return;
    }

    if (cart.hasMrpViolation) {
      final names = cart.mrpViolatedItems.map((i) => i.name).join(', ');
      _showErrorSnackBar('Sale blocked — rate exceeds MRP for: $names');
      return;
    }

    if (cart.hasStockExceededItems) {
      final item = cart.firstStockExceededItem!;
      _showErrorSnackBar(
        'Only ${_fmtQty(item.maxSellQuantity)} ${item.stockUnitLabel} available for ${item.name}',
      );
      return;
    }

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
                receiptNumber: receiptData['receiptNumber']?.toString() ?? '',
                total: (receiptData['total'] as num?)?.toDouble() ?? 0,
                paymentMode: receiptData['paymentMode']?.toString() ?? 'CASH',
                customerName: cart.contactName,
                completedAt: DateTime.now(),
              ),
            );
      }

      // Earn loyalty points — fire and forget, never block POS flow
      if (cart.contactId != null && receiptId != null) {
        _earnLoyaltyPoints(
          contactId: cart.contactId!,
          saleTotal: cart.total,
          receiptId: receiptId,
        );
      }

      // Redeem queued wallet points — fire and forget
      if (_walletRedeemAmount > 0 &&
          _walletRedeemContactId != null &&
          _walletRedeemContactId == cart.contactId &&
          receiptId != null) {
        _redeemLoyaltyPoints(
          contactId: _walletRedeemContactId!,
          redeemAmount: _walletRedeemAmount,
          receiptId: receiptId,
        );
        // Reset redemption state
        _walletRedeemAmount = 0;
        _walletRedeemContactId = null;
      }

      // Save prescription records — fire and forget, never block POS flow
      if (receiptId != null) {
        _savePrescriptionRecords(receiptId, cart);
      }

      // Refresh recent bills and clear cart for next sale
      ref.invalidate(recentPosReceiptsProvider);
      ref.read(posCartProvider.notifier).clear();
      _searchFocusNode.requestFocus();
    } catch (e) {
      if (!mounted) return;
      final message =
          e is DioException ? ApiErrorParser.message(e) : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
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
      'receiptDate':
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      'paymentMode': paymentResult['paymentMode'],
      'amountReceived': paymentResult['amountReceived'],
      if (paymentResult['upiReference'] != null)
        'upiReference': paymentResult['upiReference'],
      'gstInvoice': paymentResult['gstInvoice'] ?? false,
      if (cart.notes != null) 'notes': cart.notes,
      'lines': cart.items
          .map((item) => {
                if (item.itemId != null) 'itemId': item.itemId,
                'description': item.name,
                'quantity': item.quantity,
                if (item.unit != null) 'unit': item.unit,
                'rate': item.effectiveRate,
                'taxInclusive': true,
                if (item.discountPct > 0) 'discountPct': item.discountPct,
                if (item.taxGroupId != null) 'taxGroupId': item.taxGroupId,
                if (item.hsnCode != null) 'hsnCode': item.hsnCode,
                if (item.batchId != null) 'batchId': item.batchId,
                if (item.isWeightBased) 'weightBased': true,
                if (item.unitUomId != null) 'unitUomId': item.unitUomId,
                if (item.unitConversionFactor != null)
                  'unitConversionFactor': item.unitConversionFactor,
                if (item.isFreeItem) 'freeItem': true,
                if (item.appliedSchemeId != null)
                  'appliedSchemeId': item.appliedSchemeId,
                if (item.prescriptionNumber != null)
                  'prescriptionNumber': item.prescriptionNumber,
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

  /// Fire-and-forget: earn loyalty points after a successful sale.
  /// Never throws — errors are swallowed so the POS flow is never interrupted.
  void _earnLoyaltyPoints({
    required String contactId,
    required double saleTotal,
    required String receiptId,
  }) {
    final earnedAmount = (saleTotal / 100).floor();
    ref
        .read(walletRepositoryProvider)
        .earnPoints(
          contactId: contactId,
          saleTotal: saleTotal,
          receiptId: receiptId,
        )
        .then((_) {
      if (mounted && earnedAmount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '₹$earnedAmount loyalty point${earnedAmount == 1 ? '' : 's'} added to wallet'),
            backgroundColor: KColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
        // Invalidate wallet cache so next open shows fresh balance
        ref.invalidate(contactWalletProvider(contactId));
      }
    }).catchError((e) {
      debugPrint('[POS] earnLoyaltyPoints failed (non-blocking): $e');
    });
  }

  /// Called when the cashier confirms a wallet redemption amount from the chip dialog.
  void _onWalletRedeem(double amount, PosCartState cart) {
    if (amount <= 0 || cart.contactId == null) return;
    setState(() {
      _walletRedeemAmount = amount;
      _walletRedeemContactId = cart.contactId;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '₹${amount.toStringAsFixed(0)} wallet redemption queued — will be applied at checkout'),
        backgroundColor: KColors.success,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Clear',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _walletRedeemAmount = 0;
              _walletRedeemContactId = null;
            });
          },
        ),
      ),
    );
  }

  /// Fire-and-forget: redeem loyalty points after a successful sale.
  void _redeemLoyaltyPoints({
    required String contactId,
    required double redeemAmount,
    required String receiptId,
  }) {
    ref
        .read(walletRepositoryProvider)
        .redeemPoints(
          contactId: contactId,
          redeemAmount: redeemAmount,
          receiptId: receiptId,
        )
        .then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '₹${redeemAmount.toStringAsFixed(0)} redeemed from wallet'),
            backgroundColor: KColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
        ref.invalidate(contactWalletProvider(contactId));
      }
    }).catchError((e) {
      debugPrint('[POS] redeemLoyaltyPoints failed (non-blocking): $e');
    });
  }

  /// Groups cart items by prescriptionNumber and posts a prescription record
  /// for each unique Rx number. Fire-and-forget — never blocks the POS flow.
  void _savePrescriptionRecords(String receiptId, PosCartState cart) {
    // Collect items that have a prescriptionNumber
    final prescribedItems =
        cart.items.where((i) => i.prescriptionNumber != null).toList();
    if (prescribedItems.isEmpty) return;

    // Group by prescriptionNumber
    final Map<String, List<CartItem>> grouped = {};
    for (final item in prescribedItems) {
      final rxNum = item.prescriptionNumber!;
      grouped.putIfAbsent(rxNum, () => []).add(item);
    }

    final repo = ref.read(prescriptionRepositoryProvider);
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    for (final entry in grouped.entries) {
      final rxNumber = entry.key;
      final items = entry.value;

      final payload = {
        if (cart.contactId != null) 'contactId': cart.contactId,
        'receiptId': receiptId,
        'prescriptionNumber': rxNumber,
        'prescribedDate': todayStr,
        'items': items
            .map((i) => {
                  'itemName': i.name,
                  'quantity': i.quantity,
                  if (i.itemId != null) 'itemId': i.itemId,
                })
            .toList(),
      };

      repo.create(payload).catchError((e) {
        debugPrint(
            '[POS] _savePrescriptionRecords failed for Rx $rxNumber: $e');
        return <String, dynamic>{};
      });
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

      final receiptNumber = receiptData['receiptNumber']?.toString() ?? '';
      final total = (receiptData['total'] as num?)?.toDouble() ?? 0;
      final paymentMode = receiptData['paymentMode']?.toString() ?? 'CASH';

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

  String _fmtQty(double qty) {
    return qty == qty.roundToDouble()
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);
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

  // ── AppBar actions ───────────────────────────────────────────

  List<Widget> _buildAppBarActions(
      BuildContext context, PosCartState posCartState) {
    final narrow = MediaQuery.of(context).size.width < 430;
    final hasItems = posCartState.items.isNotEmpty;

    final hasNote =
        posCartState.notes != null && posCartState.notes!.isNotEmpty;

    final primary = <Widget>[
      const PosCustomerButton(),
      if (posCartState.hasCustomer) ...[
        const SizedBox(width: 4),
        WalletBalanceChip(
          contactId: posCartState.contactId!,
          cartTotal: posCartState.total,
          onRedeem: (amount) => _onWalletRedeem(amount, posCartState),
        ),
      ],
      const SizedBox(width: 4),
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
      if (hasItems)
        IconButton(
          onPressed: _showCartDiscount,
          icon: const Icon(Icons.discount_outlined, size: 20),
          tooltip: 'Apply cart discount',
        ),
      IconButton(
        onPressed: _showNotesDialog,
        icon: Icon(
          hasNote ? Icons.note : Icons.note_outlined,
          size: 20,
          color: hasNote ? KColors.primary : null,
        ),
        tooltip: hasNote
            ? 'Edit note (${posCartState.notes})'
            : 'Add note to receipt',
      ),
      if (hasItems)
        IconButton(
          onPressed: _holdCart,
          icon: const Icon(Icons.pause_circle_outline, size: 20),
          tooltip: 'Hold cart (F4)',
        ),
      _HeldCartsBadge(onTap: _recallCart),
    ];

    if (narrow) {
      // Collapse Clear + Settings into overflow menu on small screens
      return [
        ...primary,
        PopupMenuButton<_PosOverflowAction>(
          icon: const Icon(Icons.more_vert, size: 20),
          onSelected: (action) {
            switch (action) {
              case _PosOverflowAction.clear:
                ref.read(posCartProvider.notifier).clear();
              case _PosOverflowAction.settings:
                context.push('/pos/receipt-settings');
              case _PosOverflowAction.discount:
                _showCartDiscount();
              case _PosOverflowAction.notes:
                _showNotesDialog();
            }
          },
          itemBuilder: (_) => [
            if (hasItems)
              const PopupMenuItem(
                value: _PosOverflowAction.discount,
                child: ListTile(
                  leading: Icon(Icons.discount_outlined),
                  title: Text('Apply discount'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            const PopupMenuItem(
              value: _PosOverflowAction.notes,
              child: ListTile(
                leading: Icon(Icons.note_outlined),
                title: Text('Add note'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            if (hasItems)
              const PopupMenuItem(
                value: _PosOverflowAction.clear,
                child: ListTile(
                  leading: Icon(Icons.clear_all),
                  title: Text('Clear cart'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            const PopupMenuItem(
              value: _PosOverflowAction.settings,
              child: ListTile(
                leading: Icon(Icons.settings_outlined),
                title: Text('Receipt settings'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ];
    }

    // Wide screen — show all actions inline
    return [
      ...primary,
      if (hasItems)
        TextButton.icon(
          onPressed: () => ref.read(posCartProvider.notifier).clear(),
          icon: const Icon(Icons.clear_all, size: 18),
          label: const Text('Clear'),
        ),
      IconButton(
        icon: const Icon(Icons.settings_outlined, size: 20),
        onPressed: () => context.push('/pos/receipt-settings'),
        tooltip: 'Receipt settings',
      ),
      const SizedBox(width: 4),
    ];
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
              title: _PosSessionTitle(),
              actions: _buildAppBarActions(context, cart),
            ),
            body: Row(
              children: [
                Expanded(
                  child: Column(
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
                if (_showRecentPanel)
                  _RecentTransactionsPanel(
                    onClose: () => setState(() => _showRecentPanel = false),
                    onAction: _handleRecentAction,
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
      return SingleChildScrollView(
        child: Column(
          children: [
            PosFavouritesGrid(onItemTap: _addToCart),
            KSpacing.vGapMd,
            const PosRecentBills(),
            KSpacing.vGapMd,
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.point_of_sale,
                      size: 48,
                      color: Theme.of(context).colorScheme.outlineVariant),
                  KSpacing.vGapSm,
                  Text('Ready to sell',
                      style: KTypography.labelLarge.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                  KSpacing.vGapSm,
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

enum _PosOverflowAction { clear, settings, discount, notes }

/// AppBar title showing "Quick POS" + live session sales summary.
class _PosSessionTitle extends ConsumerWidget {
  const _PosSessionTitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txns = ref.watch(recentTransactionsProvider);
    final sessionTotal = txns.fold<double>(0, (sum, t) => sum + t.total);
    final billCount = txns.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Quick POS',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        if (billCount > 0)
          Text(
            '${CurrencyFormatter.formatIndian(sessionTotal)} · $billCount bill${billCount == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.55),
              fontWeight: FontWeight.w400,
            ),
          ),
      ],
    );
  }
}

class _RecentTransactionsPanel extends ConsumerWidget {
  final VoidCallback onClose;
  final Future<void> Function(Map<String, String>) onAction;

  const _RecentTransactionsPanel({
    required this.onClose,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final transactions = ref.watch(recentTransactionsProvider);

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          left: BorderSide(color: cs.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, size: 18),
                KSpacing.hGapSm,
                Text('Recent Sales', style: KTypography.labelLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (transactions.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long,
                        size: 40, color: cs.outlineVariant),
                    KSpacing.vGapSm,
                    Text('No recent sales',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: transactions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final tx = transactions[i];
                  final ago = DateTime.now().difference(tx.completedAt);
                  final agoText = ago.inMinutes < 1
                      ? 'just now'
                      : ago.inMinutes < 60
                          ? '${ago.inMinutes}m ago'
                          : '${ago.inHours}h ago';

                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    onTap: () =>
                        context.push('/sales-receipts/${tx.receiptId}'),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            tx.receiptNumber,
                            style: KTypography.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(agoText,
                            style: KTypography.bodySmall.copyWith(
                                color: KColors.textSecondary, fontSize: 10)),
                      ],
                    ),
                    subtitle: Text(
                      tx.customerName ?? 'Walk-in',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary, fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          CurrencyFormatter.formatIndian(tx.total),
                          style: KTypography.amountSmall,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.print, size: 16),
                          onPressed: () => onAction(
                              {'action': 'print', 'receiptId': tx.receiptId}),
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          tooltip: 'Reprint',
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, size: 16),
                          onPressed: () => onAction({
                            'action': 'whatsapp',
                            'receiptId': tx.receiptId
                          }),
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          tooltip: 'WhatsApp',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
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
