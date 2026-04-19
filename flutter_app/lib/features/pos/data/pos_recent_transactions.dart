import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecentTransaction {
  final String receiptId;
  final String receiptNumber;
  final double total;
  final String paymentMode;
  final String? customerName;
  final DateTime completedAt;

  RecentTransaction({
    required this.receiptId,
    required this.receiptNumber,
    required this.total,
    required this.paymentMode,
    this.customerName,
    required this.completedAt,
  });
}

class RecentTransactionsNotifier extends StateNotifier<List<RecentTransaction>> {
  static const maxRecent = 5;

  RecentTransactionsNotifier() : super([]);

  void add(RecentTransaction tx) {
    state = [tx, ...state].take(maxRecent).toList();
  }

  void clear() => state = [];
}

final recentTransactionsProvider =
    StateNotifierProvider<RecentTransactionsNotifier, List<RecentTransaction>>((ref) {
  return RecentTransactionsNotifier();
});
