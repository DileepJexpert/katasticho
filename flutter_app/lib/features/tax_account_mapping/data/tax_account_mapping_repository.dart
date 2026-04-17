import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

/// Backend `TaxAccountMappingResponse` for one TaxRate row.
class TaxAccountMappingDto {
  final String taxRateId;
  final String name;
  final String? rateCode;
  final double percentage;
  final String? taxType;
  final String? glOutputAccountId;
  final String? glOutputAccountCode;
  final String? glOutputAccountName;
  final String? glInputAccountId;
  final String? glInputAccountCode;
  final String? glInputAccountName;
  final bool recoverable;
  final bool customized;

  const TaxAccountMappingDto({
    required this.taxRateId,
    required this.name,
    required this.rateCode,
    required this.percentage,
    required this.taxType,
    required this.glOutputAccountId,
    required this.glOutputAccountCode,
    required this.glOutputAccountName,
    required this.glInputAccountId,
    required this.glInputAccountCode,
    required this.glInputAccountName,
    required this.recoverable,
    required this.customized,
  });

  factory TaxAccountMappingDto.fromJson(Map<String, dynamic> j) =>
      TaxAccountMappingDto(
        taxRateId: j['taxRateId']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        rateCode: j['rateCode']?.toString(),
        percentage: (j['percentage'] as num?)?.toDouble() ?? 0,
        taxType: j['taxType']?.toString(),
        glOutputAccountId: j['glOutputAccountId']?.toString(),
        glOutputAccountCode: j['glOutputAccountCode']?.toString(),
        glOutputAccountName: j['glOutputAccountName']?.toString(),
        glInputAccountId: j['glInputAccountId']?.toString(),
        glInputAccountCode: j['glInputAccountCode']?.toString(),
        glInputAccountName: j['glInputAccountName']?.toString(),
        recoverable: j['recoverable'] as bool? ?? false,
        customized: j['customized'] as bool? ?? false,
      );

  String get displayLabel {
    final pct = percentage.toStringAsFixed(
      percentage.truncateToDouble() == percentage ? 0 : 2,
    );
    return '$name ($pct%)';
  }
}

/// One line in the bulk PUT body — pass null on either side to clear it.
class TaxAccountMappingUpdate {
  final String taxRateId;
  final String? glOutputAccountId;
  final String? glInputAccountId;

  const TaxAccountMappingUpdate({
    required this.taxRateId,
    required this.glOutputAccountId,
    required this.glInputAccountId,
  });

  Map<String, dynamic> toJson() => {
        'taxRateId': taxRateId,
        'glOutputAccountId': glOutputAccountId,
        'glInputAccountId': glInputAccountId,
      };
}

final taxAccountMappingRepositoryProvider =
    Provider<TaxAccountMappingRepository>((ref) {
  return TaxAccountMappingRepository(ref.watch(apiClientProvider));
});

class TaxAccountMappingRepository {
  final ApiClient _api;
  TaxAccountMappingRepository(this._api);

  Future<List<TaxAccountMappingDto>> list() async {
    final resp = await _api.get(ApiConfig.taxAccountMappings);
    return _parseList(resp.data);
  }

  Future<List<TaxAccountMappingDto>> update(
    List<TaxAccountMappingUpdate> mappings,
  ) async {
    final resp = await _api.put(
      ApiConfig.taxAccountMappings,
      data: {'mappings': mappings.map((m) => m.toJson()).toList()},
    );
    return _parseList(resp.data);
  }

  Future<List<TaxAccountMappingDto>> reset() async {
    final resp = await _api.post(ApiConfig.taxAccountMappingsReset);
    return _parseList(resp.data);
  }

  List<TaxAccountMappingDto> _parseList(dynamic raw) {
    final body = raw as Map<String, dynamic>;
    final data = body['data'];
    final list = data is List
        ? data.cast<Map<String, dynamic>>()
        : const <Map<String, dynamic>>[];
    return list.map(TaxAccountMappingDto.fromJson).toList();
  }
}

final taxAccountMappingsProvider =
    FutureProvider.autoDispose<List<TaxAccountMappingDto>>((ref) async {
  return ref.watch(taxAccountMappingRepositoryProvider).list();
});
