import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final bankAutoMatchRepositoryProvider = Provider<BankAutoMatchRepository>((ref) {
  return BankAutoMatchRepository(ref.watch(apiClientProvider));
});

class AutoMatchSuggestionDto {
  final String id;
  final String orgId;
  final String bankAccountId;
  final String statementDate;
  final String? statementReference;
  final String? statementDescription;
  final double statementAmount;
  final bool isCredit;
  final String? matchedJournalEntryId;
  final int confidenceScore;
  final String matchReason;
  final String status;
  final String createdAt;

  const AutoMatchSuggestionDto({
    required this.id,
    required this.orgId,
    required this.bankAccountId,
    required this.statementDate,
    this.statementReference,
    this.statementDescription,
    required this.statementAmount,
    required this.isCredit,
    this.matchedJournalEntryId,
    required this.confidenceScore,
    required this.matchReason,
    required this.status,
    required this.createdAt,
  });

  factory AutoMatchSuggestionDto.fromJson(Map<String, dynamic> json) {
    return AutoMatchSuggestionDto(
      id: json['id'] as String,
      orgId: json['orgId'] as String,
      bankAccountId: json['bankAccountId'] as String,
      statementDate: json['statementDate'] as String,
      statementReference: json['statementReference'] as String?,
      statementDescription: json['statementDescription'] as String?,
      statementAmount: (json['statementAmount'] as num).toDouble(),
      isCredit: json['isCredit'] as bool? ?? true,
      matchedJournalEntryId: json['matchedJournalEntryId'] as String?,
      confidenceScore: json['confidenceScore'] as int? ?? 0,
      matchReason: json['matchReason'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      createdAt: json['createdAt'] as String,
    );
  }
}

class BankAutoMatchRepository {
  final ApiClient _api;
  BankAutoMatchRepository(this._api);

  Future<List<AutoMatchSuggestionDto>> listSuggestions(String bankAccountId, {String? status}) async {
    final res = await _api.get(
      ApiConfig.bankAutoMatchSuggestions,
      queryParameters: {
        'bankAccountId': bankAccountId,
        if (status != null && status != 'ALL') 'status': status,
      },
    );
    final list = (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return list.map((e) => AutoMatchSuggestionDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<AutoMatchSuggestionDto>> runAutoMatch(String bankAccountId, List<Map<String, dynamic>> statementLines) async {
    final res = await _api.post(
      ApiConfig.bankAutoMatchRun,
      data: {
        'bankAccountId': bankAccountId,
        'statementLines': statementLines,
      },
    );
    final list = (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return list.map((e) => AutoMatchSuggestionDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AutoMatchSuggestionDto> acceptSuggestion(String id) async {
    final res = await _api.post(ApiConfig.bankAutoMatchAccept(id));
    final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return AutoMatchSuggestionDto.fromJson(data);
  }

  Future<AutoMatchSuggestionDto> rejectSuggestion(String id) async {
    final res = await _api.post(ApiConfig.bankAutoMatchReject(id));
    final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return AutoMatchSuggestionDto.fromJson(data);
  }

  Future<int> bulkAccept(String bankAccountId, {int minScore = 80}) async {
    final res = await _api.post(
      ApiConfig.bankAutoMatchBulkAccept,
      queryParameters: {
        'bankAccountId': bankAccountId,
        'minScore': minScore,
      },
    );
    final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return (data['acceptedCount'] as num).toInt();
  }
}