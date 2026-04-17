import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final taxGroupRepositoryProvider =
    Provider<TaxGroupRepository>((ref) {
  return TaxGroupRepository(ref.watch(apiClientProvider));
});

/// Pre-fetches tax groups once and caches them in a [FutureProvider].
///
/// Each tax group contains:
///   - `id`, `name`, `description`, `active`
///   - `rates` — list of constituent tax rates with `name`, `rate`, etc.
///   - `totalRate` — sum of all constituent rate percentages
///
/// Use [taxGroupsProvider] to access the cached list.
final taxGroupsProvider =
    FutureProvider<List<TaxGroupDto>>((ref) async {
  final repo = ref.watch(taxGroupRepositoryProvider);
  return repo.listTaxGroups();
});

class TaxGroupRepository {
  final ApiClient _api;

  TaxGroupRepository(this._api);

  Future<List<TaxGroupDto>> listTaxGroups() async {
    final response = await _api.get(ApiConfig.taxGroups);
    final data = response.data as Map<String, dynamic>;
    final content = data['data'];
    final list = content is List
        ? content.cast<Map<String, dynamic>>()
        : (content is Map
            ? ((content['content'] as List?)
                    ?.cast<Map<String, dynamic>>() ??
                [])
            : <Map<String, dynamic>>[]);
    return list.map((e) => TaxGroupDto(e)).toList();
  }
}

/// Typed wrapper for a tax group from the API.
class TaxGroupDto {
  final Map<String, dynamic> raw;

  const TaxGroupDto(this.raw);

  String get id => raw['id']?.toString() ?? '';
  String get name => raw['name'] as String? ?? '';
  String get description => raw['description'] as String? ?? '';
  bool get active => raw['active'] as bool? ?? true;

  /// Sum of all constituent tax rates in this group.
  double get totalRate {
    // Try pre-computed field first
    final precomputed = raw['totalRate'] as num?;
    if (precomputed != null) return precomputed.toDouble();
    // Otherwise sum from rates list
    final ratesList = rates;
    if (ratesList.isEmpty) return 0;
    return ratesList.fold(0.0, (sum, r) => sum + r.rate);
  }

  List<TaxRateDto> get rates => (raw['rates'] as List? ?? [])
      .map((r) => TaxRateDto(r as Map<String, dynamic>))
      .toList();

  /// Display label: "GST 18%" or "IGST 18%"
  String get displayLabel {
    final pct = totalRate.toStringAsFixed(
        totalRate.truncateToDouble() == totalRate ? 0 : 1);
    return '$name $pct%';
  }
}

class TaxRateDto {
  final Map<String, dynamic> raw;

  const TaxRateDto(this.raw);

  String get id => raw['id']?.toString() ?? '';
  String get name => raw['name'] as String? ?? '';
  double get rate => (raw['percentage'] as num? ?? raw['rate'] as num?)?.toDouble() ?? 0;
}
