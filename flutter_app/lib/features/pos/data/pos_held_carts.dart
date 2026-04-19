import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pos_cart_state.dart';

class HeldCart {
  final String id;
  final String label;
  final PosCartState cart;
  final DateTime heldAt;

  HeldCart({
    required this.id,
    required this.label,
    required this.cart,
    required this.heldAt,
  });
}

class HeldCartsNotifier extends StateNotifier<List<HeldCart>> {
  static const maxHeld = 5;

  HeldCartsNotifier() : super([]);

  bool get canHold => state.length < maxHeld;

  void hold(PosCartState cart, {String? label}) {
    if (!canHold || cart.isEmpty) return;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final heldLabel = label ??
        (cart.hasCustomer
            ? cart.contactName ?? 'Cart'
            : 'Cart ${state.length + 1}');
    state = [
      ...state,
      HeldCart(id: id, label: heldLabel, cart: cart, heldAt: DateTime.now()),
    ];
  }

  PosCartState? recall(String id) {
    final index = state.indexWhere((h) => h.id == id);
    if (index < 0) return null;
    final cart = state[index].cart;
    state = [...state]..removeAt(index);
    return cart;
  }

  void remove(String id) {
    state = state.where((h) => h.id != id).toList();
  }

  void clear() {
    state = [];
  }
}

final heldCartsProvider =
    StateNotifierProvider<HeldCartsNotifier, List<HeldCart>>((ref) {
  return HeldCartsNotifier();
});
