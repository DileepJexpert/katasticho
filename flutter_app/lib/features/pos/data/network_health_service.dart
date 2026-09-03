import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

enum NetworkQuality {
  excellent, // < 80ms
  good,      // 80-250ms
  degraded,  // 250-800ms
  offline,   // > 800ms or connection drop
}

class NetworkHealthState {
  final NetworkQuality quality;
  final int latencyMs;
  final double packetSuccessRate; // 0.0 - 1.0 (last 10 pings)
  final List<int> latencyHistory;
  final DateTime lastChecked;
  final String connectionType; // WiFi, Cellular, Ethernet, None

  const NetworkHealthState({
    required this.quality,
    required this.latencyMs,
    required this.packetSuccessRate,
    required this.latencyHistory,
    required this.lastChecked,
    required this.connectionType,
  });

  bool get isOnline => quality != NetworkQuality.offline;

  String get qualityLabel {
    switch (quality) {
      case NetworkQuality.excellent:
        return 'Fast ($latencyMs ms)';
      case NetworkQuality.good:
        return 'Stable ($latencyMs ms)';
      case NetworkQuality.degraded:
        return 'Slow ($latencyMs ms)';
      case NetworkQuality.offline:
        return 'Offline';
    }
  }
}

final networkHealthProvider = StateNotifierProvider<NetworkHealthNotifier, NetworkHealthState>((ref) {
  final client = ref.watch(apiClientProvider);
  return NetworkHealthNotifier(client);
});

class NetworkHealthNotifier extends StateNotifier<NetworkHealthState> {
  final ApiClient _client;
  Timer? _pingTimer;
  StreamSubscription? _connectivitySub;
  final List<int> _recentPings = [];
  final List<bool> _pingSuccesses = [];

  NetworkHealthNotifier(this._client)
      : super(NetworkHealthState(
          quality: NetworkQuality.good,
          latencyMs: 45,
          packetSuccessRate: 1.0,
          latencyHistory: const [45, 50, 42, 48],
          lastChecked: DateTime.now(),
          connectionType: 'WiFi',
        )) {
    _init();
  }

  void _init() {
    _startConnectivityListener();
    _startPingTimer();
    probeHealth();
  }

  void _startConnectivityListener() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isNone = results.every((r) => r == ConnectivityResult.none);
      if (isNone) {
        state = NetworkHealthState(
          quality: NetworkQuality.offline,
          latencyMs: 0,
          packetSuccessRate: 0.0,
          latencyHistory: state.latencyHistory,
          lastChecked: DateTime.now(),
          connectionType: 'None',
        );
      } else {
        probeHealth();
      }
    });
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      probeHealth();
    });
  }

  Future<void> probeHealth() async {
    final connectivity = await Connectivity().checkConnectivity();
    String connType = 'WiFi';
    if (connectivity.contains(ConnectivityResult.ethernet)) {
      connType = 'Ethernet';
    } else if (connectivity.contains(ConnectivityResult.mobile)) {
      connType = 'Cellular';
    } else if (connectivity.contains(ConnectivityResult.none)) {
      connType = 'None';
    }

    if (connType == 'None') {
      _recordPing(0, false, connType);
      return;
    }

    final stopwatch = Stopwatch()..start();
    try {
      // Lightweight auth check or timestamp endpoint
      await _client.get('/api/v1/auth/me');
      stopwatch.stop();
      final ms = stopwatch.elapsedMilliseconds;
      _recordPing(ms, true, connType);
    } catch (e) {
      stopwatch.stop();
      _recordPing(stopwatch.elapsedMilliseconds, false, connType);
    }
  }

  void _recordPing(int latencyMs, bool success, String connType) {
    _pingSuccesses.add(success);
    if (_pingSuccesses.length > 10) _pingSuccesses.removeAt(0);

    if (success) {
      _recentPings.add(latencyMs);
      if (_recentPings.length > 10) _recentPings.removeAt(0);
    }

    final successCount = _pingSuccesses.where((s) => s).length;
    final rate = _pingSuccesses.isNotEmpty ? successCount / _pingSuccesses.length : 0.0;

    NetworkQuality quality;
    if (!success || rate < 0.5) {
      quality = NetworkQuality.offline;
    } else if (latencyMs < 80) {
      quality = NetworkQuality.excellent;
    } else if (latencyMs < 250) {
      quality = NetworkQuality.good;
    } else {
      quality = NetworkQuality.degraded;
    }

    state = NetworkHealthState(
      quality: quality,
      latencyMs: latencyMs,
      packetSuccessRate: rate,
      latencyHistory: List.unmodifiable(_recentPings),
      lastChecked: DateTime.now(),
      connectionType: connType,
    );
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}