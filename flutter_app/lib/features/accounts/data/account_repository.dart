import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

/// One Chart-of-Accounts row.
class AccountDto {
  final String id;
  final String code;
  final String name;
  final String type;
  final String? subType;
  final String? parentId;
  final String? parentAccountName;
  final int level;
  final bool isSystem;
  final bool isInvolvedInTransaction;
  final bool hasChildren;
  final int childCount;
  final String? description;
  final double openingBalance;
  final String currency;
  final bool isActive;
  final bool isDeleted;

  const AccountDto({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.subType,
    this.parentId,
    this.parentAccountName,
    required this.level,
    required this.isSystem,
    this.isInvolvedInTransaction = false,
    this.hasChildren = false,
    this.childCount = 0,
    this.description,
    required this.openingBalance,
    required this.currency,
    required this.isActive,
    required this.isDeleted,
  });

  factory AccountDto.fromJson(Map<String, dynamic> j) => AccountDto(
        id: j['id']?.toString() ?? '',
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        type: j['type']?.toString() ?? '',
        subType: j['subType']?.toString(),
        parentId: j['parentId']?.toString(),
        parentAccountName: j['parentAccountName']?.toString(),
        level: (j['level'] as num?)?.toInt() ?? 1,
        isSystem: j['isSystem'] as bool? ?? false,
        isInvolvedInTransaction: j['isInvolvedInTransaction'] as bool? ?? false,
        hasChildren: j['hasChildren'] as bool? ?? false,
        childCount: (j['childCount'] as num?)?.toInt() ?? 0,
        description: j['description']?.toString(),
        openingBalance: (j['openingBalance'] as num?)?.toDouble() ?? 0.0,
        currency: j['currency']?.toString() ?? 'INR',
        isActive: j['isActive'] as bool? ?? true,
        isDeleted: j['isDeleted'] as bool? ?? false,
      );

  String get display => '$code — $name';

  String get categoryLabel => switch (type.toUpperCase()) {
        'ASSET' => 'Asset',
        'LIABILITY' => 'Liability',
        'EQUITY' => 'Equity',
        'REVENUE' || 'INCOME' => 'Income',
        'EXPENSE' => 'Expense',
        _ => type,
      };
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

  Future<Map<String, dynamic>> listRaw() async {
    final resp = await _api.get(ApiConfig.chartOfAccounts);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAccount(String id) async {
    final resp = await _api.get('${ApiConfig.chartOfAccounts}/$id');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createAccount(Map<String, dynamic> data) async {
    final resp = await _api.post(ApiConfig.chartOfAccounts, data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateAccount(String id, Map<String, dynamic> data) async {
    final resp = await _api.put('${ApiConfig.chartOfAccounts}/$id', data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<void> deleteAccount(String id) async {
    await _api.delete('${ApiConfig.chartOfAccounts}/$id');
  }

  Future<void> activateAccount(String id) async {
    await _api.patch('${ApiConfig.chartOfAccounts}/$id/activate');
  }

  Future<void> deactivateAccount(String id) async {
    await _api.patch('${ApiConfig.chartOfAccounts}/$id/deactivate');
  }

  Future<Map<String, dynamic>> getBalance(String id) async {
    final resp = await _api.get('${ApiConfig.chartOfAccounts}/$id/balance');
    return resp.data as Map<String, dynamic>;
  }

  Future<List<AccountTransactionDto>> getTransactions(String id) async {
    final resp = await _api.get('${ApiConfig.chartOfAccounts}/$id/transactions');
    final body = resp.data as Map<String, dynamic>;
    final raw = body['data'];
    final list = raw is List ? raw.cast<Map<String, dynamic>>() : const <Map<String, dynamic>>[];
    return list.map(AccountTransactionDto.fromJson).toList();
  }
}

/// One posted journal line as seen from an account's transaction history.
class AccountTransactionDto {
  final String lineId;
  final String journalEntryId;
  final String entryNumber;
  final DateTime effectiveDate;
  final String sourceModule;
  final String? entryDescription;
  final String? lineDescription;
  final double debit;
  final double credit;
  final String currency;

  const AccountTransactionDto({
    required this.lineId,
    required this.journalEntryId,
    required this.entryNumber,
    required this.effectiveDate,
    required this.sourceModule,
    this.entryDescription,
    this.lineDescription,
    required this.debit,
    required this.credit,
    required this.currency,
  });

  factory AccountTransactionDto.fromJson(Map<String, dynamic> j) => AccountTransactionDto(
        lineId: j['lineId']?.toString() ?? '',
        journalEntryId: j['journalEntryId']?.toString() ?? '',
        entryNumber: j['entryNumber']?.toString() ?? '',
        effectiveDate: DateTime.tryParse(j['effectiveDate']?.toString() ?? '') ?? DateTime.now(),
        sourceModule: j['sourceModule']?.toString() ?? '',
        entryDescription: j['entryDescription']?.toString(),
        lineDescription: j['lineDescription']?.toString(),
        debit: (j['debit'] as num?)?.toDouble() ?? 0.0,
        credit: (j['credit'] as num?)?.toDouble() ?? 0.0,
        currency: j['currency']?.toString() ?? 'INR',
      );
}

final accountTransactionsProvider =
    FutureProvider.autoDispose.family<List<AccountTransactionDto>, String>(
  (ref, id) async {
    return ref.watch(accountRepositoryProvider).getTransactions(id);
  },
);

/// Cached list — invalidate on any COA change.
final accountsProvider = FutureProvider.autoDispose<List<AccountDto>>((ref) async {
  return ref.watch(accountRepositoryProvider).list();
});

/// Full raw list with category filter (null = all).
final accountListProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String?>(
  (ref, type) async {
    return ref.watch(accountRepositoryProvider).listRaw();
  },
);
