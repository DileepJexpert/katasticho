import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/storage/pos_database.dart';

const _dbName = 'katasticho_offline.db';
const _table = 'pending_receipts';
const _itemTable = 'pos_item_cache';
const _metaTable = 'pos_meta';

class PendingReceipt {
  final int? id;
  final String requestJson;
  final String createdAt;
  final int retryCount;
  final String? lastError;

  PendingReceipt({
    this.id,
    required this.requestJson,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  Map<String, dynamic> get requestBody => jsonDecode(requestJson) as Map<String, dynamic>;
}

class OfflinePosService {
  OfflinePosService._();
  static final instance = OfflinePosService._();

  Database? _db;
  StreamSubscription? _connectivitySub;
  bool _syncing = false;

  final _pendingCountController = StreamController<int>.broadcast();
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  Future<Database> _getDb() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, _dbName),
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            request_json TEXT NOT NULL,
            created_at TEXT NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0,
            last_error TEXT
          )
        ''');
        await _createItemCache(db);
        await _createMeta(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createItemCache(db);
        if (oldVersion < 3) await _createMeta(db);
      },
    );
    return _db!;
  }

  Future<void> _createItemCache(Database db) {
    return db.execute('''
      CREATE TABLE $_itemTable (
        item_id TEXT PRIMARY KEY,
        name TEXT,
        sku TEXT,
        barcode TEXT,
        search_text TEXT,
        result_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createMeta(Database db) {
    return db.execute('''
      CREATE TABLE $_metaTable (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  Future<String?> getMeta(String key) async {
    if (!posOfflineSupported) return null;
    final db = await _getDb();
    final rows = await db.query(_metaTable, where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setMeta(String key, String value) async {
    if (!posOfflineSupported) return;
    final db = await _getDb();
    await db.insert(_metaTable, {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Remove an item from the local catalog (used when sync reports isDeleted).
  Future<void> removeCachedItem(String itemId) async {
    if (!posOfflineSupported) return;
    final db = await _getDb();
    await db.delete(_itemTable, where: 'item_id = ?', whereArgs: [itemId]);
  }

  /// Next client-side receipt number for an offline sale (e.g. "OFF-0007").
  /// The server assigns the real number when the queued receipt syncs; this is
  /// what the cashier prints/shows the customer in the meantime.
  Future<String> nextOfflineReceiptNumber() async {
    if (!posOfflineSupported) return 'OFF';
    final cur = int.tryParse(await getMeta('offline_receipt_seq') ?? '0') ?? 0;
    final next = cur + 1;
    await setMeta('offline_receipt_seq', next.toString());
    return 'OFF-${next.toString().padLeft(4, '0')}';
  }

  /// Optimistically reduce cached stock for items just sold offline, so the
  /// next offline sale sees the lower count. (Single-counter assumption — the
  /// server is still the source of truth and reconciles on sync.)
  Future<void> decrementCachedStock(List<Map<String, dynamic>> sold) async {
    if (!posOfflineSupported) return;
    try {
      final db = await _getDb();
      for (final s in sold) {
        final id = s['itemId']?.toString();
        final qty = (s['qty'] as num?)?.toDouble() ?? 0;
        if (id == null || qty <= 0) continue;
        final rows =
            await db.query(_itemTable, where: 'item_id = ?', whereArgs: [id]);
        if (rows.isEmpty) continue;
        final json =
            jsonDecode(rows.first['result_json'] as String) as Map<String, dynamic>;
        final cur = (json['currentStock'] as num?)?.toDouble() ?? 0;
        json['currentStock'] = cur - qty;
        await db.update(_itemTable, {'result_json': jsonEncode(json)},
            where: 'item_id = ?', whereArgs: [id]);
      }
    } catch (e) {
      debugPrint('[OfflinePOS] decrementCachedStock failed: $e');
    }
  }

  Future<void> init() async {
    if (!posOfflineSupported) return;
    await _getDb();
    _emitCount();
    _startConnectivityListener();
  }

  void _startConnectivityListener() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        syncPendingReceipts();
      }
    });
  }

  Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<void> queueReceipt(Map<String, dynamic> requestBody) async {
    if (!posOfflineSupported) return;
    final db = await _getDb();
    await db.insert(_table, {
      'request_json': jsonEncode(requestBody),
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
    });
    _emitCount();
    debugPrint('[OfflinePOS] Receipt queued locally');
  }

  // ── Offline catalog cache ──────────────────────────────────────────────
  // Item search/prices/stock are online by default; caching successful search
  // results (and a periodic full sync) lets POS search + billing keep working
  // when the network drops at the counter.

  /// Upsert POS search results into the local catalog cache (fire-and-forget).
  Future<void> cacheItems(List<Map<String, dynamic>> items) async {
    if (!posOfflineSupported || items.isEmpty) return;
    try {
      final db = await _getDb();
      final batch = db.batch();
      final now = DateTime.now().toIso8601String();
      for (final it in items) {
        final id = (it['itemId'] ?? it['id'])?.toString();
        if (id == null || id.isEmpty) continue;
        final name = (it['name'] ?? '').toString();
        final sku = (it['sku'] ?? '').toString();
        final barcode = (it['barcode'] ?? '').toString();
        batch.insert(
          _itemTable,
          {
            'item_id': id,
            'name': name,
            'sku': sku,
            'barcode': barcode,
            'search_text': '$name $sku $barcode'.toLowerCase(),
            'result_json': jsonEncode(it),
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('[OfflinePOS] cacheItems failed: $e');
    }
  }

  /// Offline ranked search over the cached catalog: barcode exact > SKU prefix
  /// > name/text contains.
  Future<List<Map<String, dynamic>>> searchLocalItems(String query,
      {int limit = 20}) async {
    if (!posOfflineSupported) return [];
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    try {
      final db = await _getDb();
      final rows = await db.rawQuery(
        '''
        SELECT result_json,
          CASE
            WHEN lower(barcode) = ? THEN 0
            WHEN lower(sku) LIKE ? THEN 1
            WHEN search_text LIKE ? THEN 2
            ELSE 3
          END AS rank
        FROM $_itemTable
        WHERE lower(barcode) = ? OR lower(sku) LIKE ? OR search_text LIKE ?
        ORDER BY rank, name
        LIMIT ?
        ''',
        [q, '$q%', '%$q%', q, '$q%', '%$q%', limit],
      );
      return rows
          .map((r) => jsonDecode(r['result_json'] as String) as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('[OfflinePOS] searchLocalItems failed: $e');
      return [];
    }
  }

  Future<int> cachedItemCount() async {
    if (!posOfflineSupported) return 0;
    final db = await _getDb();
    return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $_itemTable')) ??
        0;
  }

  Future<int> pendingCount() async {
    final db = await _getDb();
    final result = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_table'));
    return result ?? 0;
  }

  Future<List<PendingReceipt>> getPendingReceipts() async {
    final db = await _getDb();
    final rows = await db.query(_table, orderBy: 'id ASC');
    return rows
        .map((r) => PendingReceipt(
              id: r['id'] as int?,
              requestJson: r['request_json'] as String,
              createdAt: r['created_at'] as String,
              retryCount: r['retry_count'] as int? ?? 0,
              lastError: r['last_error'] as String?,
            ))
        .toList();
  }

  Future<void> syncPendingReceipts({Ref? ref}) async {
    if (_syncing) return;
    _syncing = true;
    _syncStatusController.add(SyncStatus.syncing);

    try {
      final db = await _getDb();
      final rows = await db.query(_table, orderBy: 'id ASC', limit: 50);

      if (rows.isEmpty) {
        _syncStatusController.add(SyncStatus.idle);
        return;
      }

      int synced = 0;
      int failed = 0;

      for (final row in rows) {
        final id = row['id'] as int;
        final body = jsonDecode(row['request_json'] as String) as Map<String, dynamic>;

        try {
          final client = _getApiClient(ref);
          if (client == null) {
            debugPrint('[OfflinePOS] No API client available for sync');
            break;
          }
          await client.post(ApiConfig.salesReceipts, data: body);
          await db.delete(_table, where: 'id = ?', whereArgs: [id]);
          synced++;
        } catch (e) {
          final retryCount = (row['retry_count'] as int? ?? 0) + 1;
          await db.update(
            _table,
            {'retry_count': retryCount, 'last_error': e.toString()},
            where: 'id = ?',
            whereArgs: [id],
          );
          failed++;
          if (retryCount >= 5) {
            debugPrint('[OfflinePOS] Receipt $id exceeded max retries');
          }
        }
      }

      debugPrint('[OfflinePOS] Sync complete: $synced synced, $failed failed');
      _emitCount();
      _syncStatusController.add(failed > 0 ? SyncStatus.error : SyncStatus.idle);
    } catch (e) {
      debugPrint('[OfflinePOS] Sync error: $e');
      _syncStatusController.add(SyncStatus.error);
    } finally {
      _syncing = false;
    }
  }

  ApiClient? _getApiClient(Ref? ref) {
    if (ref != null) {
      try {
        return ref.read(apiClientProvider);
      } catch (_) {}
    }
    return _cachedClient;
  }

  ApiClient? _cachedClient;
  void setApiClient(ApiClient client) {
    _cachedClient = client;
  }

  Future<void> deleteReceipt(int id) async {
    final db = await _getDb();
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    _emitCount();
  }

  Future<void> clearAll() async {
    final db = await _getDb();
    await db.delete(_table);
    _emitCount();
  }

  void _emitCount() {
    pendingCount().then((c) => _pendingCountController.add(c));
  }

  void dispose() {
    _connectivitySub?.cancel();
    _pendingCountController.close();
    _syncStatusController.close();
    _db?.close();
    _db = null;
  }
}

enum SyncStatus { idle, syncing, error }

final offlinePendingCountProvider = StreamProvider<int>((ref) {
  return OfflinePosService.instance.pendingCountStream;
});

final offlineSyncStatusProvider = StreamProvider<SyncStatus>((ref) {
  return OfflinePosService.instance.syncStatusStream;
});

/// Live network-availability for the POS connection badge. Reports whether a
/// network interface is up (not true internet reachability — a connected-but-
/// unreachable state still routes a sale through the offline path).
final posOnlineProvider = StreamProvider<bool>((ref) async* {
  bool up(List<ConnectivityResult> r) => r.any((x) => x != ConnectivityResult.none);
  yield up(await Connectivity().checkConnectivity());
  yield* Connectivity().onConnectivityChanged.map(up);
});
