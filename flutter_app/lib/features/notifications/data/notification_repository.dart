import 'dart:async';

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

  Future<Map<String, dynamic>> getNotifications({
    int page = 0,
    int size = 20,
  }) async {
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

  Future<void> markAsRead(String id) async {
    await _api.put('${ApiConfig.notifications}/$id/read', data: {});
  }

  Future<void> markAllAsRead() async {
    await _api.put(ApiConfig.notificationsReadAll, data: {});
  }
}

// ── Providers ──

/// Unread count that auto-refreshes every 60 seconds.
final unreadCountProvider =
    AutoDisposeAsyncNotifierProvider<UnreadCountNotifier, int>(
  UnreadCountNotifier.new,
);

class UnreadCountNotifier extends AutoDisposeAsyncNotifier<int> {
  Timer? _timer;

  @override
  Future<int> build() async {
    ref.onDispose(() => _timer?.cancel());

    // Start periodic refresh
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      _refresh();
    });

    return _fetch();
  }

  Future<int> _fetch() {
    return ref.read(notificationRepositoryProvider).getUnreadCount();
  }

  Future<void> _refresh() async {
    state = const AsyncLoading<int>().copyWithPrevious(state);
    state = await AsyncValue.guard(_fetch);
  }
}

/// Notification list — family by page number.
final notificationListProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, int>((ref, page) async {
  return ref.watch(notificationRepositoryProvider).getNotifications(page: page);
});
