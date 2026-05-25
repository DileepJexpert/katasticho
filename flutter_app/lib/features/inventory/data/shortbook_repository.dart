import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class ShortbookRepository {
  final ApiClient _client;
  ShortbookRepository(this._client);

  Future<List<Map<String, dynamic>>> getShortbook() async {
    final res = await _client.get('/api/v1/stock/shortbook');
    final data = res.data;
    if (data is List) return data.cast<Map<String, dynamic>>();
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }
}

final shortbookRepositoryProvider = Provider<ShortbookRepository>((ref) {
  return ShortbookRepository(ref.watch(apiClientProvider));
});

final shortbookProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(shortbookRepositoryProvider).getShortbook();
});
