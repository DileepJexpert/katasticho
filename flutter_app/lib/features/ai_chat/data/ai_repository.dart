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

  /// AI-first bill drafting: turn (reviewed) scanned bill data into a DRAFT
  /// purchase bill + AI Inbox suggestion. Returns the `data` payload with
  /// `suggestionId`, `billId`, `billNumber`, `vendorCreated`, `warnings`, etc.
  Future<Map<String, dynamic>> draftBillFromScan(
      Map<String, dynamic> billData) async {
    final response = await _api.post(ApiConfig.aiBillDrafts, data: billData);
    final body = response.data as Map<String, dynamic>;
    return Map<String, dynamic>.from((body['data'] as Map?) ?? const {});
  }

  /// Approve a drafted bill — posts it through the AP path. Returns the
  /// posted bill summary (`status` becomes OPEN).
  Future<Map<String, dynamic>> approveBillDraft(String suggestionId) async {
    final response = await _api.post(ApiConfig.aiBillDraftApprove(suggestionId));
    final body = response.data as Map<String, dynamic>;
    return Map<String, dynamic>.from((body['data'] as Map?) ?? const {});
  }

  /// Reject a drafted bill — deletes the DRAFT.
  Future<void> rejectBillDraft(String suggestionId, {String? reason}) async {
    await _api.post(
      ApiConfig.aiBillDraftReject(suggestionId),
      data: reason != null && reason.trim().isNotEmpty
          ? {'reason': reason.trim()}
          : null,
    );
  }

  /// Conversational entry: turn a sentence ("paid 5000 cash for shop rent")
  /// into a DRAFT journal entry + AI Inbox suggestion. Returns the `data`
  /// payload: `drafted`, `suggestionId`, `voucherType`, `lines`, `warnings`,
  /// `message`.
  Future<Map<String, dynamic>> draftEntry(String text) async {
    final response = await _api.post(ApiConfig.aiEntry, data: {'text': text});
    final body = response.data as Map<String, dynamic>;
    return Map<String, dynamic>.from((body['data'] as Map?) ?? const {});
  }

  /// Approve a drafted entry — posts it through the journal gate.
  Future<Map<String, dynamic>> approveEntryDraft(String suggestionId) async {
    final response = await _api.post(ApiConfig.aiEntryApprove(suggestionId));
    final body = response.data as Map<String, dynamic>;
    return Map<String, dynamic>.from((body['data'] as Map?) ?? const {});
  }

  /// Reject a drafted entry — deletes the DRAFT.
  Future<void> rejectEntryDraft(String suggestionId, {String? reason}) async {
    await _api.post(
      ApiConfig.aiEntryReject(suggestionId),
      data: reason != null && reason.trim().isNotEmpty
          ? {'reason': reason.trim()}
          : null,
    );
  }

  /// Run the proactive sweep now (collections reminders, month-close checklist,
  /// anomaly scan). Returns counts: `collections`, `monthClose`, `anomalies`.
  Future<Map<String, dynamic>> runProactiveSweep() async {
    final response = await _api.post(ApiConfig.aiProactiveRun);
    final body = response.data as Map<String, dynamic>;
    return Map<String, dynamic>.from((body['data'] as Map?) ?? const {});
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
