import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final savedReportRepositoryProvider = Provider<SavedReportRepository>((ref) {
  return SavedReportRepository(ref.watch(apiClientProvider));
});

class SavedReportRepository {
  final ApiClient _api;
  SavedReportRepository(this._api);

  Future<Map<String, dynamic>> list() async {
    final res = await _api.get(ApiConfig.savedReports);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> create({
    required String name,
    String? description,
    required String baseReportKey,
    required List<String> columnKeys,
    Map<String, dynamic>? filters,
    List<String> tags = const [],
    bool isPublic = false,
  }) async {
    final res = await _api.post(ApiConfig.savedReports, data: {
      'name': name,
      'description': description,
      'baseReportKey': baseReportKey,
      'columnKeys': columnKeys,
      'filters': filters ?? {},
      'tags': tags,
      'isPublic': isPublic,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(String id, {
    required String name,
    String? description,
    required String baseReportKey,
    required List<String> columnKeys,
    Map<String, dynamic>? filters,
    List<String> tags = const [],
    bool isPublic = false,
  }) async {
    final res = await _api.put(ApiConfig.savedReportById(id), data: {
      'name': name,
      'description': description,
      'baseReportKey': baseReportKey,
      'columnKeys': columnKeys,
      'filters': filters ?? {},
      'tags': tags,
      'isPublic': isPublic,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<void> delete(String id) async {
    await _api.delete(ApiConfig.savedReportById(id));
  }

  Future<Map<String, dynamic>> listSchedules(String id) async {
    final res = await _api.get(ApiConfig.savedReportSchedules(id));
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addSchedule(String id, {
    required String frequency,
    int? dayOfWeek,
    int? dayOfMonth,
    required String sendTime,
    required List<String> recipientEmails,
    String? subjectTemplate,
    bool active = true,
  }) async {
    final res = await _api.post(ApiConfig.savedReportSchedules(id), data: {
      'frequency': frequency,
      if (dayOfWeek != null) 'dayOfWeek': dayOfWeek,
      if (dayOfMonth != null) 'dayOfMonth': dayOfMonth,
      'sendTime': sendTime,
      'recipientEmails': recipientEmails,
      if (subjectTemplate != null) 'subjectTemplate': subjectTemplate,
      'active': active,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteSchedule(String reportId, String scheduleId) async {
    await _api.delete(ApiConfig.savedReportScheduleById(reportId, scheduleId));
  }
}
