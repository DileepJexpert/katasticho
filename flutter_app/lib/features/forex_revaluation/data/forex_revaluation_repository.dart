import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final forexRevaluationRepositoryProvider =
    Provider<ForexRevaluationRepository>((ref) {
  return ForexRevaluationRepository(ref.watch(apiClientProvider));
});

/// Period-end forex revaluation — restates open foreign-currency AR/AP to the
/// closing rate and posts the unrealized gain/loss (+ next-day reversal).
/// Backend: `/api/v1/reports/forex-revaluation` (ForexRevaluationController).
class ForexRevaluationRepository {
  final ApiClient _api;
  ForexRevaluationRepository(this._api);

  /// Compute the revaluation without posting — review before you run.
  Future<Map<String, dynamic>> preview(String asOfDate) async {
    final res = await _api.get(
      ApiConfig.forexRevaluationPreview,
      queryParameters: {'asOfDate': asOfDate},
    );
    final data = res.data['data'];
    return data is Map<String, dynamic> ? data : {};
  }

  /// Post the consolidated revaluation journal + its next-day reversal.
  Future<Map<String, dynamic>> run(String asOfDate) async {
    final res = await _api.post(
      ApiConfig.forexRevaluationRun,
      queryParameters: {'asOfDate': asOfDate},
    );
    final data = res.data['data'];
    return data is Map<String, dynamic> ? data : {};
  }

  Future<List<dynamic>> runs() async {
    final res = await _api.get(ApiConfig.forexRevaluationRuns);
    final data = res.data['data'];
    if (data is List) return data;
    return [];
  }
}
