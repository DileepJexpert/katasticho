import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  return ContactRepository(ref.watch(apiClientProvider));
});

class ContactRepository {
  final ApiClient _api;

  ContactRepository(this._api);

  Future<Map<String, dynamic>> listContacts({
    int page = 0,
    int size = 20,
    String? type,
    String? search,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (type != null) 'type': type,
      if (search != null && search.isNotEmpty) 'search': search,
    };
    debugPrint('[ContactRepo] listContacts params: $params');
    final response = await _api.get(ApiConfig.contacts, queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getContact(String id) async {
    debugPrint('[ContactRepo] getContact id: $id');
    final response = await _api.get('${ApiConfig.contacts}/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createContact(Map<String, dynamic> data) async {
    debugPrint('[ContactRepo] createContact: $data');
    final response = await _api.post(ApiConfig.contacts, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateContact(
      String id, Map<String, dynamic> data) async {
    debugPrint('[ContactRepo] updateContact id: $id');
    final response = await _api.put('${ApiConfig.contacts}/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteContact(String id) async {
    debugPrint('[ContactRepo] deleteContact id: $id');
    await _api.delete('${ApiConfig.contacts}/$id');
  }
}

// ── Providers ──

final contactListProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String?>(
  (ref, type) async {
    final repo = ref.watch(contactRepositoryProvider);
    return repo.listContacts(type: type);
  },
);

/// Contact search provider — searches by name/phone, filtered by type.
final contactSearchProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({String? type, String? search})>(
  (ref, params) async {
    final repo = ref.watch(contactRepositoryProvider);
    return repo.listContacts(type: params.type, search: params.search);
  },
);
