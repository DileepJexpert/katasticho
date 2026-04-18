import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  return CommentRepository(ref.watch(apiClientProvider));
});

class CommentRepository {
  final ApiClient _api;
  CommentRepository(this._api);

  Future<List<Map<String, dynamic>>> getComments(
      String entityType, String entityId) async {
    final response =
        await _api.get(ApiConfig.comments(entityType, entityId));
    final data = response.data;
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> addComment(
      String entityType, String entityId, String text) async {
    final response = await _api.post(
      ApiConfig.comments(entityType, entityId),
      data: {'text': text},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteComment(String id) async {
    await _api.delete(ApiConfig.commentById(id));
  }
}

/// Provider family keyed by (entityType, entityId).
final commentsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, ({String entityType, String entityId})>(
  (ref, key) async {
    final repo = ref.watch(commentRepositoryProvider);
    return repo.getComments(key.entityType, key.entityId);
  },
);
