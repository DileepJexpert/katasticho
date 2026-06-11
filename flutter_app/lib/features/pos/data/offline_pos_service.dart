import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

const _dbName = 'katasticho_offline.db';
const _table = 'pending_receipts';

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
      version: 1,
      onCreate: (db, version) {
        return db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            request_json TEXT NOT NULL,
            created_at TEXT NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0,
            last_error TEXT
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> init() async {
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
    final db = await _getDb();
    await db.insert(_table, {
      'request_json': jsonEncode(requestBody),
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
    });
    _emitCount();
    debugPrint('[OfflinePOS] Receipt queued locally');
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
