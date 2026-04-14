import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
});

class NotificationRepository {
  final ApiClient _api;

  NotificationRepository(this._api);

  Future<Map<String, dynamic>> listNotifications({int page = 0, int size = 20}) async {
    final response = await _api.get(
      ApiConfig.notifications,
      queryParameters: {'page': page, 'size': size},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _api.get(ApiConfig.notificationsUnreadCount);
      final data = response.data as Map<String, dynamic>;
      final payload = data['data'] ?? data;
      return (payload['count'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('[NotificationRepo] getUnreadCount error: $e');
      return 0;
    }
  }

  Future<void> markRead(String id) async {
    await _api.put('${ApiConfig.notifications}/$id/read', data: {});
  }

  Future<void> markAllRead() async {
    await _api.put('${ApiConfig.notificationsReadAll}', data: {});
  }
}

// ── Providers ──

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  return ref.watch(notificationRepositoryProvider).getUnreadCount();
});

final notificationListProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(notificationRepositoryProvider).listNotifications();
});
