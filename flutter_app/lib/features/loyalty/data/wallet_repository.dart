import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

class WalletRepository {
  final ApiClient _client;
  WalletRepository(this._client);

  /// GET /api/v1/wallet/contact/{contactId}
  Future<Map<String, dynamic>?> getWallet(String contactId) async {
    debugPrint('[WalletRepo] getWallet contactId=$contactId');
    try {
      final res = await _client.get(ApiConfig.walletByContact(contactId));
      final body = res.data as Map<String, dynamic>;
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (e, st) {
      debugPrint('[WalletRepo] getWallet FAILED: $e\n$st');
      rethrow;
    }
  }

  /// GET /api/v1/wallet/contact/{contactId}/transactions
  Future<List<Map<String, dynamic>>> getTransactions(String contactId) async {
    debugPrint('[WalletRepo] getTransactions contactId=$contactId');
    try {
      final res =
          await _client.get(ApiConfig.walletTransactions(contactId));
      final body = res.data as Map<String, dynamic>;
      final data = body['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
      return const [];
    } catch (e, st) {
      debugPrint('[WalletRepo] getTransactions FAILED: $e\n$st');
      rethrow;
    }
  }

  /// GET /api/v1/wallet/contact/{contactId}/redeemable?saleTotal=...
  Future<Map<String, dynamic>?> getRedeemable(
      String contactId, double saleTotal) async {
    debugPrint(
        '[WalletRepo] getRedeemable contactId=$contactId saleTotal=$saleTotal');
    try {
      final res = await _client.get(
        ApiConfig.walletRedeemable(contactId),
        queryParameters: {'saleTotal': saleTotal},
      );
      final body = res.data as Map<String, dynamic>;
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (e, st) {
      debugPrint('[WalletRepo] getRedeemable FAILED: $e\n$st');
      rethrow;
    }
  }

  /// POST /api/v1/wallet/earn
  Future<Map<String, dynamic>> earnPoints({
    required String contactId,
    required double saleTotal,
    required String receiptId,
  }) async {
    debugPrint(
        '[WalletRepo] earnPoints contactId=$contactId saleTotal=$saleTotal receiptId=$receiptId');
    try {
      final res = await _client.post(
        ApiConfig.walletEarn,
        data: {
          'contactId': contactId,
          'saleTotal': saleTotal,
          'receiptId': receiptId,
        },
      );
      final body = res.data as Map<String, dynamic>;
      return (body['data'] as Map<String, dynamic>?) ?? body;
    } catch (e, st) {
      debugPrint('[WalletRepo] earnPoints FAILED: $e\n$st');
      rethrow;
    }
  }

  /// POST /api/v1/wallet/redeem
  Future<Map<String, dynamic>> redeemPoints({
    required String contactId,
    required double redeemAmount,
    required String receiptId,
  }) async {
    debugPrint(
        '[WalletRepo] redeemPoints contactId=$contactId redeemAmount=$redeemAmount receiptId=$receiptId');
    try {
      final res = await _client.post(
        ApiConfig.walletRedeem,
        data: {
          'contactId': contactId,
          'redeemAmount': redeemAmount,
          'receiptId': receiptId,
        },
      );
      final body = res.data as Map<String, dynamic>;
      return (body['data'] as Map<String, dynamic>?) ?? body;
    } catch (e, st) {
      debugPrint('[WalletRepo] redeemPoints FAILED: $e\n$st');
      rethrow;
    }
  }
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(apiClientProvider));
});

/// Provider for a specific contact's wallet balance.
final contactWalletProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>(
  (ref, contactId) {
    return ref.read(walletRepositoryProvider).getWallet(contactId);
  },
);

/// Provider for a specific contact's wallet transaction history.
final contactWalletTransactionsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, contactId) {
    return ref.read(walletRepositoryProvider).getTransactions(contactId);
  },
);
