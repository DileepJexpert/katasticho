import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Single item in the POS cart — tax-aware with batch/stock info.
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
  final String? batchNumber;
  final double taxRate;
  final String? batchExpiry;
  final double currentStock;
  final bool isWeightBased;
  final double? mrp;
  double quantity;
  final String? unitUomId;
  final double? unitConversionFactor;
  final List<Map<String, dynamic>> availableUnits;

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
    this.batchNumber,
    this.taxRate = 0,
    this.batchExpiry,
    this.currentStock = 0,
    this.isWeightBased = false,
    this.mrp,
    this.quantity = 1,
    this.unitUomId,
    this.unitConversionFactor,
    this.availableUnits = const [],
  });

  double get lineTotal => rate * quantity;
  double get taxAmount => lineTotal * taxRate / 100;
  double get lineTotalWithTax => lineTotal + taxAmount;

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
    String? batchNumber,
    double? taxRate,
    String? batchExpiry,
    double? currentStock,
    bool? isWeightBased,
    double? mrp,
    double? quantity,
    String? unitUomId,
    double? unitConversionFactor,
    List<Map<String, dynamic>>? availableUnits,
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
      batchNumber: batchNumber ?? this.batchNumber,
      taxRate: taxRate ?? this.taxRate,
      batchExpiry: batchExpiry ?? this.batchExpiry,
      currentStock: currentStock ?? this.currentStock,
      isWeightBased: isWeightBased ?? this.isWeightBased,
      mrp: mrp ?? this.mrp,
      quantity: quantity ?? this.quantity,
      unitUomId: unitUomId ?? this.unitUomId,
      unitConversionFactor: unitConversionFactor ?? this.unitConversionFactor,
      availableUnits: availableUnits ?? this.availableUnits,
    );
  }
}

/// A single payment split in a mixed-payment sale.
class PaymentSplit {
  final String mode; // CASH, UPI, CARD
  final double amount;
  final String? reference;

  const PaymentSplit({
    required this.mode,
    required this.amount,
    this.reference,
  });

  PaymentSplit copyWith({String? mode, double? amount, String? reference}) {
    return PaymentSplit(
      mode: mode ?? this.mode,
      amount: amount ?? this.amount,
      reference: reference ?? this.reference,
    );
  }
}

/// Full cart state — items + payment mode + amounts + customer.
class PosCartState {
  final List<CartItem> items;
  final String paymentMode; // CASH, UPI, CARD — primary mode
  final double amountReceived;
  final String? upiReference;
  final List<PaymentSplit> paymentSplits;
  final String? contactId;
  final String? contactName;
  final String? contactPhone;
  final String? notes;

  const PosCartState({
    this.items = const [],
    this.paymentMode = 'CASH',
    this.amountReceived = 0,
    this.upiReference,
    this.paymentSplits = const [],
    this.contactId,
    this.contactName,
    this.contactPhone,
    this.notes,
  });

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.lineTotal);
  double get taxAmount => items.fold(0.0, (sum, item) => sum + item.taxAmount);
  double get total => subtotal + taxAmount;
  int get itemCount => items.length;
  int get totalQuantity =>
      items.fold(0, (sum, item) => sum + item.quantity.ceil());
  bool get isEmpty => items.isEmpty;
  double get changeReturned =>
      amountReceived > total ? amountReceived - total : 0;

  /// Whether a customer is selected (not walk-in).
  bool get hasCustomer => contactId != null;

  bool get isSplitPayment => paymentSplits.isNotEmpty;
  double get splitTotal =>
      paymentSplits.fold(0.0, (sum, s) => sum + s.amount);

  PosCartState copyWith({
    List<CartItem>? items,
    String? paymentMode,
    double? amountReceived,
    String? upiReference,
    List<PaymentSplit>? paymentSplits,
    String? contactId,
    bool clearContact = false,
    String? contactName,
    String? contactPhone,
    String? notes,
  }) {
    return PosCartState(
      items: items ?? this.items,
      paymentMode: paymentMode ?? this.paymentMode,
      amountReceived: amountReceived ?? this.amountReceived,
      upiReference: upiReference ?? this.upiReference,
      paymentSplits: paymentSplits ?? this.paymentSplits,
      contactId: clearContact ? null : (contactId ?? this.contactId),
      contactName: clearContact ? null : (contactName ?? this.contactName),
      contactPhone: clearContact ? null : (contactPhone ?? this.contactPhone),
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
      updated[existing] = updated[existing].copyWith(
        quantity: updated[existing].quantity + item.quantity,
      );
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
      updated[index] = updated[index].copyWith(quantity: quantity);
    }
    state = state.copyWith(items: updated);
  }

  /// Set exact quantity for item at index (from manual qty entry).
  void setQuantity(int index, double quantity) {
    updateQuantity(index, quantity);
  }

  /// Increment quantity for item at index.
  void incrementQty(int index) {
    if (index < 0 || index >= state.items.length) return;
    final updated = List<CartItem>.from(state.items);
    updated[index] = updated[index].copyWith(
      quantity: updated[index].quantity + 1,
    );
    state = state.copyWith(items: updated);
  }

  /// Decrement quantity for item at index (removes if reaches 0).
  void decrementQty(int index) {
    if (index < 0 || index >= state.items.length) return;
    final updated = List<CartItem>.from(state.items);
    final newQty = updated[index].quantity - 1;
    if (newQty <= 0) {
      updated.removeAt(index);
    } else {
      updated[index] = updated[index].copyWith(quantity: newQty);
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
  void setContact(String? id, String? name, [String? phone]) {
    if (id == null) {
      state = state.copyWith(clearContact: true);
    } else {
      state = state.copyWith(
          contactId: id, contactName: name, contactPhone: phone);
    }
  }

  /// Clear customer — revert to Walk-in.
  void clearContact() {
    state = state.copyWith(clearContact: true);
  }

  /// Set notes.
  void setNotes(String? notes) {
    state = state.copyWith(notes: notes);
  }

  /// Set payment splits for mixed payment.
  void setPaymentSplits(List<PaymentSplit> splits) {
    state = state.copyWith(paymentSplits: splits);
  }

  /// Clear payment splits.
  void clearPaymentSplits() {
    state = state.copyWith(paymentSplits: []);
  }

  /// Change the unit for a cart item (e.g. switch from PCS to DOZEN).
  void changeUnit(int index, String unit, String? uomId, double? conversionFactor, double? customPrice) {
    if (index < 0 || index >= state.items.length) return;
    final updated = List<CartItem>.from(state.items);
    final item = updated[index];
    double newRate = item.rate;
    if (customPrice != null && customPrice > 0) {
      newRate = customPrice;
    } else if (conversionFactor != null && conversionFactor > 0) {
      newRate = item.rate * conversionFactor;
    }
    updated[index] = item.copyWith(
      unit: unit,
      rate: newRate,
      unitUomId: uomId,
      unitConversionFactor: conversionFactor,
    );
    state = state.copyWith(items: updated);
  }

  /// Clear cart — after successful sale.
  void clear() {
    state = const PosCartState();
  }

  /// Restore a held cart.
  void restore(PosCartState cart) {
    state = cart;
  }
}

/// Cart provider — global singleton for the POS session.
final posCartProvider =
    StateNotifierProvider<PosCartNotifier, PosCartState>((ref) {
  return PosCartNotifier();
});
