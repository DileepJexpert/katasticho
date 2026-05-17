import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import 'ai_inbox_models.dart';

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(ref.watch(apiClientProvider));
});

class AiRepository {
  final ApiClient _api;

  AiRepository(this._api);

  /// Send a natural language query and get financial insights.
  Future<Map<String, dynamic>> query(String message) async {
    final response = await _api.post(
      ApiConfig.aiQuery,
      data: {'message': message},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Upload a bill image for scanning via Claude Vision.
  Future<Map<String, dynamic>> scanBill(String base64Image) async {
    final response = await _api.post(
      ApiConfig.aiScanBill,
      data: {'image': base64Image},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Scan a product label to extract item details.
  Future<Map<String, dynamic>> scanProductLabel(String base64Image,
      {String? mediaType}) async {
    final response = await _api.post(
      ApiConfig.aiScanProductLabel,
      data: {
        'image': base64Image,
        if (mediaType != null) 'mediaType': mediaType
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Scan a purchase invoice to extract multiple item details.
  Future<Map<String, dynamic>> scanPurchaseInvoice(String base64Image,
      {String? mediaType}) async {
    final response = await _api.post(
      ApiConfig.aiScanPurchaseInvoice,
      data: {
        'image': base64Image,
        if (mediaType != null) 'mediaType': mediaType
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<AiInboxSummary> getSuggestionSummary() async {
    final response = await _api.get(ApiConfig.aiSuggestionsSummary);
    final body = response.data as Map<String, dynamic>;
    final data = Map<String, dynamic>.from((body['data'] as Map?) ?? const {});
    return AiInboxSummary.fromMap(data);
  }

  Future<AiSuggestionPage> listSuggestions({
    String? status,
    int page = 0,
    int size = 20,
  }) async {
    final response = await _api.get(
      ApiConfig.aiSuggestions,
      queryParameters: {
        'page': page,
        'size': size,
        if (status != null && status.isNotEmpty && status != 'ALL')
          'status': status,
      },
    );
    final body = response.data as Map<String, dynamic>;
    final data = Map<String, dynamic>.from((body['data'] as Map?) ?? const {});
    return AiSuggestionPage.fromMap(data);
  }

  Future<AiSuggestionItem> reviewSuggestion(
    String id, {
    required String action,
    Map<String, dynamic>? reviewedValue,
    String? correctionReason,
  }) async {
    final response = await _api.post(
      ApiConfig.aiSuggestionReview(id),
      data: {
        'action': action,
        if (reviewedValue != null) 'reviewedValue': reviewedValue,
        if (correctionReason != null && correctionReason.trim().isNotEmpty)
          'correctionReason': correctionReason.trim(),
      },
    );
    final body = response.data as Map<String, dynamic>;
    final data = Map<String, dynamic>.from((body['data'] as Map?) ?? const {});
    return AiSuggestionItem.fromMap(data);
  }
}
