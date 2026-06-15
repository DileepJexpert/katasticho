import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/storage/pos_database.dart';
import 'offline_pos_service.dart';

/// Pulls catalog deltas from the server into the local POS cache so search /
/// cart / GST run instantly (local SQLite, no network in the hot path).
///
/// - On POS open: one delta sync (cheap — only changed items since `lastSync`).
/// - In the background: a ~60s periodic delta sync (no UI block).
/// - On reconnect: another delta sync.
class PosCatalogSyncService {
  PosCatalogSyncService._();
  static final instance = PosCatalogSyncService._();

  static const _lastSyncKey = 'pos_catalog_last_sync';
  static const _pageSize = 500;
  static const _interval = Duration(seconds: 60);

  ApiClient? _api;
  Timer? _timer;
  bool _running = false;

  void attach(ApiClient api) {
    _api = api;
  }

  /// Start a periodic background sync (idempotent — calling again resets the
  /// timer). Also runs one sync immediately. Pair with [stop] when the POS
  /// screen is closed.
  void start() {
    if (!posOfflineSupported) return;
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => syncNow());
    // Fire-and-forget an immediate sync — won't block the UI.
    unawaited(syncNow());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// One delta sync pass. Pages through `hasMore` until the server is caught up.
  /// Safe to call from anywhere (e.g. on reconnect).
  Future<void> syncNow() async {
    if (!posOfflineSupported) return;
    final api = _api;
    if (api == null) return;
    if (_running) return; // skip overlapping ticks
    _running = true;
    try {
      final offline = OfflinePosService.instance;
      String? since = await offline.getMeta(_lastSyncKey);
      int passes = 0;
      while (passes < 10) {
        passes++;
        final params = <String, dynamic>{
          'page_size': _pageSize,
          if (since != null) 'since': since,
        };
        final res =
            await api.get(ApiConfig.posSync, queryParameters: params);
        final data = (res.data as Map?)?['data'] as Map?;
        if (data == null) break;
        final items = (data['items'] as List?)
                ?.whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            const [];
        final nextSince = data['nextSince']?.toString();
        final hasMore = data['hasMore'] == true;

        if (items.isNotEmpty) {
          // Partition deletes vs upserts so the local cache prunes stale rows.
          final alive = <Map<String, dynamic>>[];
          for (final it in items) {
            final deleted = it['isDeleted'] == true;
            final id = (it['itemId'] ?? it['id'])?.toString();
            if (deleted && id != null) {
              await offline.removeCachedItem(id);
            } else {
              alive.add(it);
            }
          }
          if (alive.isNotEmpty) await offline.cacheItems(alive);
        }

        if (nextSince != null && nextSince.isNotEmpty) {
          since = nextSince;
          await offline.setMeta(_lastSyncKey, since);
        }
        if (!hasMore || items.isEmpty) break;
      }
    } catch (e) {
      // Background sync — never throw, never block the cashier.
      debugPrint('[PosCatalogSync] sync failed: $e');
    } finally {
      _running = false;
    }
  }
}

final posCatalogSyncProvider = Provider<PosCatalogSyncService>((ref) {
  final svc = PosCatalogSyncService.instance;
  svc.attach(ref.read(apiClientProvider));
  return svc;
});
