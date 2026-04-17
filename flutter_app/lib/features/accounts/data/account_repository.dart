import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

/// One Chart-of-Accounts row, surfaced in pickers across Settings.
class AccountDto {
  final String id;
  final String code;
  final String name;
  final String? type;
  final String? subType;
  final bool isDeleted;

  const AccountDto({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.subType,
    required this.isDeleted,
  });

  factory AccountDto.fromJson(Map<String, dynamic> j) => AccountDto(
        id: j['id']?.toString() ?? '',
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        type: j['type']?.toString(),
        subType: j['subType']?.toString(),
        isDeleted: j['isDeleted'] as bool? ?? false,
      );

  String get display => '$code — $name';
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(apiClientProvider));
});

class AccountRepository {
  final ApiClient _api;
  AccountRepository(this._api);

  Future<List<AccountDto>> list() async {
    final resp = await _api.get(ApiConfig.chartOfAccounts);
    final body = resp.data as Map<String, dynamic>;
    final raw = body['data'];
    final list = raw is List ? raw.cast<Map<String, dynamic>>() : const <Map<String, dynamic>>[];
    return list
        .map(AccountDto.fromJson)
        .where((a) => !a.isDeleted)
        .toList();
  }
}

/// Cached chart-of-accounts — invalidate on CoA edits.
final accountsProvider =
    FutureProvider.autoDispose<List<AccountDto>>((ref) async {
  return ref.watch(accountRepositoryProvider).list();
});
