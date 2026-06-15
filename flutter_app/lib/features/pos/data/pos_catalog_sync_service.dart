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
  static const _lastSyncIdKey = 'pos_catalog_last_sync_id';
  static const _pageSize = 500;
  static const _interval = Duration(seconds: 60);

  ApiClient? _api;
  Timer? _timer;
  bool _running = false;

  /// Streams pre-sync progress: {processed, total} as the cashier watches the
  /// download. {total: 0} means "starting / no count yet".
  final _progressController =
      StreamController<PosCatalogSyncProgress>.broadcast();
  Stream<PosCatalogSyncProgress> get progressStream =>
      _progressController.stream;

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

  /// One delta sync pass (capped at [maxPasses] pages). Pages through
  /// `hasMore` until either the server is caught up or the cap is hit. Safe
  /// to call from anywhere (e.g. on reconnect). Never throws.
  Future<int> syncNow({int maxPasses = 10, bool emitProgress = false}) async {
    if (!posOfflineSupported) return 0;
    final api = _api;
    if (api == null) return 0;
    if (_running) return 0; // skip overlapping ticks
    _running = true;
    int totalRows = 0;
    try {
      final offline = OfflinePosService.instance;
      String? since = await offline.getMeta(_lastSyncKey);
      String? sinceId = await offline.getMeta(_lastSyncIdKey);
      int totalCount = 0;
      int passes = 0;
      while (passes < maxPasses) {
        passes++;
        final params = <String, dynamic>{
          'page_size': _pageSize,
          if (since != null) 'since': since,
          if (sinceId != null) 'since_id': sinceId,
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
        final nextSinceId = data['nextSinceId']?.toString();
        final hasMore = data['hasMore'] == true;
        if (totalCount == 0) {
          totalCount = (data['totalCount'] as num?)?.toInt() ?? 0;
        }

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
        if (nextSinceId != null && nextSinceId.isNotEmpty) {
          sinceId = nextSinceId;
          await offline.setMeta(_lastSyncIdKey, sinceId);
        }
        totalRows += items.length;
        if (emitProgress) {
          _progressController.add(PosCatalogSyncProgress(
              processed: await offline.cachedItemCount(),
              total: totalCount));
        }
        if (!hasMore || items.isEmpty) break;
      }
    } catch (e) {
      // Background sync — never throw, never block the cashier.
      debugPrint('[PosCatalogSync] sync failed: $e');
    } finally {
      _running = false;
    }
    return totalRows;
  }

  /// **Full catalog pre-sync** — for a fresh terminal. Drains the server in
  /// pages (up to 200 passes = 100k items at default page size), emitting
  /// progress so the UI can show a determinate bar. Idempotent: resumes from
  /// the persisted cursor if interrupted.
  Future<PosCatalogSyncProgress> fullPreSync() async {
    if (!posOfflineSupported) {
      return const PosCatalogSyncProgress(processed: 0, total: 0);
    }
    await syncNow(maxPasses: 200, emitProgress: true);
    final cached = await OfflinePosService.instance.cachedItemCount();
    final done = PosCatalogSyncProgress(processed: cached, total: cached);
    _progressController.add(done);
    return done;
  }
}

class PosCatalogSyncProgress {
  const PosCatalogSyncProgress({required this.processed, required this.total});
  final int processed;
  final int total;

  double get fraction =>
      total <= 0 ? 0 : (processed / total).clamp(0.0, 1.0).toDouble();
}

final posCatalogSyncProgressProvider =
    StreamProvider<PosCatalogSyncProgress>((ref) {
  return PosCatalogSyncService.instance.progressStream;
});

final posCatalogSyncProvider = Provider<PosCatalogSyncService>((ref) {
  final svc = PosCatalogSyncService.instance;
  svc.attach(ref.read(apiClientProvider));
  return svc;
});
