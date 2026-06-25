import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final customerReceiptRepositoryProvider =
    Provider<CustomerReceiptRepository>((ref) {
  return CustomerReceiptRepository(ref.watch(apiClientProvider));
});

/// Paginated receipt list (optionally for one customer).
final customerReceiptListProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String?>((ref, contactId) async {
  final repo = ref.watch(customerReceiptRepositoryProvider);
  return repo.listReceipts(contactId: contactId);
});

class CustomerReceiptRepository {
  final ApiClient _api;

  CustomerReceiptRepository(this._api);

  Future<Map<String, dynamic>> listReceipts({
    int page = 0,
    int size = 20,
    String? contactId,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (contactId != null) 'contact_id': contactId,
    };
    final response =
        await _api.get(ApiConfig.customerReceipts, queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getReceipt(String id) async {
    final response = await _api.get(ApiConfig.customerReceiptById(id));
    return _unwrap(response.data);
  }

  /// Record a lump-sum receipt allocated across [allocations]
  /// (each `{invoiceId, amountApplied}`); any excess parks as advance.
  Future<Map<String, dynamic>> recordReceipt({
    required String contactId,
    required double amount,
    required String paymentMethod,
    required String receiptDate,
    String? referenceNumber,
    String? notes,
    required List<Map<String, dynamic>> allocations,
  }) async {
    final body = <String, dynamic>{
      'contactId': contactId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'receiptDate': receiptDate,
      if (referenceNumber != null && referenceNumber.isNotEmpty)
        'referenceNumber': referenceNumber,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'allocations': allocations,
    };
    final response = await _api.post(ApiConfig.customerReceipts, data: body);
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> voidReceipt(String id, {String? reason}) async {
    final response = await _api.post(
      ApiConfig.voidCustomerReceipt(id),
      data: {if (reason != null) 'reason': reason},
    );
    return _unwrap(response.data);
  }

  /// Unallocated advance currently sitting on a customer.
  Future<double> availableAdvance(String contactId) async {
    final response = await _api.get(ApiConfig.customerAdvance(contactId));
    final data = _unwrap(response.data);
    return (data['availableAdvance'] as num?)?.toDouble() ?? 0;
  }

  Map<String, dynamic> _unwrap(dynamic data) {
    final map = data as Map<String, dynamic>;
    return Map<String, dynamic>.from((map['data'] ?? map) as Map);
  }
}
