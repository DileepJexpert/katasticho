import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final defaultAccountRepositoryProvider =
    Provider<DefaultAccountRepository>((ref) {
  return DefaultAccountRepository(ref.watch(apiClientProvider));
});

/// One row in Settings → Accounting → Default Accounts.
///
/// Mirrors the backend `DefaultAccountResponse` record. `overridden` is TRUE
/// when the org has explicitly bound this purpose to a non-default account.
class DefaultAccountDto {
  final String purpose;
  final String label;
  final String defaultCode;
  final String? accountId;
  final String? accountCode;
  final String? accountName;
  final bool overridden;

  const DefaultAccountDto({
    required this.purpose,
    required this.label,
    required this.defaultCode,
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.overridden,
  });

  factory DefaultAccountDto.fromJson(Map<String, dynamic> j) =>
      DefaultAccountDto(
        purpose: j['purpose']?.toString() ?? '',
        label: j['label']?.toString() ?? '',
        defaultCode: j['defaultCode']?.toString() ?? '',
        accountId: j['accountId']?.toString(),
        accountCode: j['accountCode']?.toString(),
        accountName: j['accountName']?.toString(),
        overridden: j['overridden'] as bool? ?? false,
      );

  String get displayAccount {
    if (accountCode == null && accountName == null) return defaultCode;
    return '${accountCode ?? ''} — ${accountName ?? ''}'.trim();
  }
}

/// One {purpose → accountId} pair the user is rebinding.
class DefaultAccountUpdate {
  final String purpose;
  final String accountId;
  const DefaultAccountUpdate({required this.purpose, required this.accountId});

  Map<String, dynamic> toJson() => {'purpose': purpose, 'accountId': accountId};
}

class DefaultAccountRepository {
  final ApiClient _api;
  DefaultAccountRepository(this._api);

  Future<List<DefaultAccountDto>> list() async {
    final resp = await _api.get(ApiConfig.defaultAccounts);
    final body = resp.data as Map<String, dynamic>;
    final raw = body['data'];
    final list = raw is List ? raw.cast<Map<String, dynamic>>() : const <Map<String, dynamic>>[];
    return list.map(DefaultAccountDto.fromJson).toList();
  }

  Future<List<DefaultAccountDto>> update(List<DefaultAccountUpdate> mappings) async {
    final resp = await _api.put(
      ApiConfig.defaultAccounts,
      data: {'mappings': mappings.map((m) => m.toJson()).toList()},
    );
    final body = resp.data as Map<String, dynamic>;
    final raw = body['data'];
    final list = raw is List ? raw.cast<Map<String, dynamic>>() : const <Map<String, dynamic>>[];
    return list.map(DefaultAccountDto.fromJson).toList();
  }
}

/// Cached fetch — invalidate after a successful PUT to refresh the screen.
final defaultAccountsProvider =
    FutureProvider.autoDispose<List<DefaultAccountDto>>((ref) async {
  return ref.watch(defaultAccountRepositoryProvider).list();
});
