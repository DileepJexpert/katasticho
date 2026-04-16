import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Single item in the POS cart.
class CartItem {
  final String? itemId;
  final String name;
  final String? sku;
  final String? barcode;
  final double rate;
  final String? unit;
  final String? taxGroupId;
  final String? taxGroupName;
  final String? hsnCode;
  final String? batchId;
  double quantity;

  CartItem({
    this.itemId,
    required this.name,
    this.sku,
    this.barcode,
    required this.rate,
    this.unit,
    this.taxGroupId,
    this.taxGroupName,
    this.hsnCode,
    this.batchId,
    this.quantity = 1,
  });

  double get lineTotal => rate * quantity;

  CartItem copyWith({
    String? itemId,
    String? name,
    String? sku,
    String? barcode,
    double? rate,
    String? unit,
    String? taxGroupId,
    String? taxGroupName,
    String? hsnCode,
    String? batchId,
    double? quantity,
  }) {
    return CartItem(
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      rate: rate ?? this.rate,
      unit: unit ?? this.unit,
      taxGroupId: taxGroupId ?? this.taxGroupId,
      taxGroupName: taxGroupName ?? this.taxGroupName,
      hsnCode: hsnCode ?? this.hsnCode,
      batchId: batchId ?? this.batchId,
      quantity: quantity ?? this.quantity,
    );
  }
}

/// Full cart state — items + payment mode + amounts.
class PosCartState {
  final List<CartItem> items;
  final String paymentMode; // CASH, UPI, CARD
  final double amountReceived;
  final String? upiReference;
  final String? contactId;
  final String? contactName;
  final String? notes;

  const PosCartState({
    this.items = const [],
    this.paymentMode = 'CASH',
    this.amountReceived = 0,
    this.upiReference,
    this.contactId,
    this.contactName,
    this.notes,
  });

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.lineTotal);
  int get itemCount => items.length;
  bool get isEmpty => items.isEmpty;
  double get changeReturned =>
      amountReceived > subtotal ? amountReceived - subtotal : 0;

  PosCartState copyWith({
    List<CartItem>? items,
    String? paymentMode,
    double? amountReceived,
    String? upiReference,
    String? contactId,
    String? contactName,
    String? notes,
  }) {
    return PosCartState(
      items: items ?? this.items,
      paymentMode: paymentMode ?? this.paymentMode,
      amountReceived: amountReceived ?? this.amountReceived,
      upiReference: upiReference ?? this.upiReference,
      contactId: contactId ?? this.contactId,
      contactName: contactName ?? this.contactName,
      notes: notes ?? this.notes,
    );
  }
}

/// Cart state notifier — manages add/remove/update/clear operations.
class PosCartNotifier extends StateNotifier<PosCartState> {
  PosCartNotifier() : super(const PosCartState());

  /// Add an item to cart. If same itemId exists, increment quantity.
  void addItem(CartItem item) {
    final existing = state.items.indexWhere(
      (i) => i.itemId != null && i.itemId == item.itemId,
    );
    if (existing >= 0) {
      final updated = List<CartItem>.from(state.items);
      updated[existing].quantity += item.quantity;
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(items: [...state.items, item]);
    }
  }

  /// Update quantity for item at index.
  void updateQuantity(int index, double quantity) {
    if (index < 0 || index >= state.items.length) return;
    final updated = List<CartItem>.from(state.items);
    if (quantity <= 0) {
      updated.removeAt(index);
    } else {
      updated[index].quantity = quantity;
    }
    state = state.copyWith(items: updated);
  }

  /// Remove item at index.
  void removeItem(int index) {
    if (index < 0 || index >= state.items.length) return;
    final updated = List<CartItem>.from(state.items);
    updated.removeAt(index);
    state = state.copyWith(items: updated);
  }

  /// Set payment mode (CASH, UPI, CARD).
  void setPaymentMode(String mode) {
    state = state.copyWith(paymentMode: mode);
  }

  /// Set amount received (for cash change calculation).
  void setAmountReceived(double amount) {
    state = state.copyWith(amountReceived: amount);
  }

  /// Set UPI reference.
  void setUpiReference(String? ref) {
    state = state.copyWith(upiReference: ref);
  }

  /// Set customer (contact).
  void setContact(String? id, String? name) {
    state = state.copyWith(contactId: id, contactName: name);
  }

  /// Set notes.
  void setNotes(String? notes) {
    state = state.copyWith(notes: notes);
  }

  /// Clear cart — after successful sale.
  void clear() {
    state = const PosCartState();
  }
}

/// Cart provider — global singleton for the POS session.
final posCartProvider =
    StateNotifierProvider<PosCartNotifier, PosCartState>((ref) {
  return PosCartNotifier();
});
