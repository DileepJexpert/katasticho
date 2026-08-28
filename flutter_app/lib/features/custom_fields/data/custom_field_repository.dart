import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import 'custom_field_models.dart';

final customFieldRepositoryProvider = Provider<CustomFieldRepository>((ref) {
  return CustomFieldRepository(ref.watch(apiClientProvider).dio);
});

final customFieldDefinitionsProvider =
    FutureProvider.family<List<CustomFieldDefinition>, String>((ref, entityType) async {
  final repo = ref.watch(customFieldRepositoryProvider);
  return repo.getDefinitions(entityType);
});

final allCustomFieldDefinitionsProvider =
    FutureProvider.autoDispose<List<CustomFieldDefinition>>((ref) async {
  final repo = ref.watch(customFieldRepositoryProvider);
  return repo.getAllDefinitions();
});

class CustomFieldEntityParam {
  final String entityType;
  final String entityId;

  const CustomFieldEntityParam({required this.entityType, required this.entityId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomFieldEntityParam &&
          runtimeType == other.runtimeType &&
          entityType == other.entityType &&
          entityId == other.entityId;

  @override
  int get hashCode => Object.hash(entityType, entityId);
}

final entityCustomFieldsProvider =
    FutureProvider.family<List<CustomFieldValueDTO>, CustomFieldEntityParam>(
        (ref, param) async {
  final repo = ref.watch(customFieldRepositoryProvider);
  return repo.getValues(param.entityType, param.entityId);
});

class CustomFieldRepository {
  final Dio _dio;

  CustomFieldRepository(this._dio);

  Future<List<CustomFieldDefinition>> getDefinitions(
    String entityType, {
    bool activeOnly = true,
  }) async {
    final res = await _dio.get(
      ApiConfig.customFieldDefinitions,
      queryParameters: {
        'entityType': entityType,
        'activeOnly': activeOnly,
      },
    );
    final data = res.data['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => CustomFieldDefinition.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CustomFieldDefinition>> getAllDefinitions() async {
    final res = await _dio.get(ApiConfig.customFieldDefinitionsAll);
    final data = res.data['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => CustomFieldDefinition.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CustomFieldDefinition> createDefinition(Map<String, dynamic> payload) async {
    final res = await _dio.post(
      ApiConfig.customFieldDefinitions,
      data: payload,
    );
    return CustomFieldDefinition.fromJson(
      res.data['data'] as Map<String, dynamic>,
    );
  }

  Future<CustomFieldDefinition> updateDefinition(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.put(
      ApiConfig.customFieldDefinitionById(id),
      data: payload,
    );
    return CustomFieldDefinition.fromJson(
      res.data['data'] as Map<String, dynamic>,
    );
  }

  Future<void> deleteDefinition(String id) async {
    await _dio.delete(ApiConfig.customFieldDefinitionById(id));
  }

  Future<List<CustomFieldValueDTO>> getValues(
    String entityType,
    String entityId,
  ) async {
    final res = await _dio.get(
      ApiConfig.customFieldValues(entityType, entityId),
    );
    final data = res.data['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => CustomFieldValueDTO.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CustomFieldValueDTO>> saveValues(
    String entityType,
    String entityId,
    List<CustomFieldValueInput> inputs,
  ) async {
    final res = await _dio.post(
      ApiConfig.customFieldValues(entityType, entityId),
      data: {
        'values': inputs.map((e) => e.toJson()).toList(),
      },
    );
    final data = res.data['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => CustomFieldValueDTO.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, List<CustomFieldValueDTO>>> getValuesBatch(
    String entityType,
    List<String> entityIds,
  ) async {
    final res = await _dio.post(
      ApiConfig.customFieldValuesBatch(entityType),
      data: entityIds,
    );
    final data = res.data['data'] as Map<String, dynamic>? ?? {};
    final result = <String, List<CustomFieldValueDTO>>{};
    data.forEach((key, val) {
      final list = (val as List<dynamic>?)
              ?.map((e) => CustomFieldValueDTO.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      result[key] = list;
    });
    return result;
  }
}
