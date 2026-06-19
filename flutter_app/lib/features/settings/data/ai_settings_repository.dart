import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final aiSettingsRepositoryProvider = Provider<AiSettingsRepository>((ref) {
  return AiSettingsRepository(ref.watch(apiClientProvider));
});

class AiModelSettings {
  final String provider;
  final String modelName;
  final String? baseUrl;

  const AiModelSettings({
    required this.provider,
    required this.modelName,
    this.baseUrl,
  });

  factory AiModelSettings.fromJson(Map<String, dynamic> json) {
    return AiModelSettings(
      provider: json['provider'] as String? ?? 'CLAUDE',
      modelName: json['modelName'] as String? ?? 'claude-sonnet-4-20250514',
      baseUrl: json['baseUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'modelName': modelName,
    if (baseUrl != null) 'baseUrl': baseUrl,
  };
}

class AiSettingsRepository {
  final ApiClient _api;

  AiSettingsRepository(this._api);

  Future<AiModelSettings> getSettings() async {
    final resp = await _api.get(ApiConfig.aiSettings);
    final data = (resp.data as Map<String, dynamic>)['data'] as Map<String, dynamic>?
        ?? resp.data as Map<String, dynamic>;
    return AiModelSettings.fromJson(data);
  }

  Future<AiModelSettings> updateSettings(AiModelSettings settings) async {
    final resp = await _api.put(ApiConfig.aiSettings, data: settings.toJson());
    final data = (resp.data as Map<String, dynamic>)['data'] as Map<String, dynamic>?
        ?? resp.data as Map<String, dynamic>;
    return AiModelSettings.fromJson(data);
  }

  Future<bool> testConnection(String baseUrl) async {
    try {
      final resp = await _api.post(ApiConfig.aiSettingsTest, data: {'baseUrl': baseUrl});
      final data = (resp.data as Map<String, dynamic>)['data'] as Map<String, dynamic>?
          ?? resp.data as Map<String, dynamic>;
      return data['success'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  /// The models actually installed on the local server (what `ollama list`
  /// shows). Empty list if the server is unreachable.
  Future<List<String>> listInstalledModels(String baseUrl) async {
    try {
      final resp = await _api.get(ApiConfig.aiSettingsModels,
          queryParameters: {'baseUrl': baseUrl});
      final data = (resp.data as Map<String, dynamic>)['data'] as List?;
      return (data ?? const []).map((e) => e.toString()).toList();
    } catch (_) {
      return const [];
    }
  }
}
