import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final creditReminderRepositoryProvider =
    Provider<CreditReminderRepository>((ref) {
  return CreditReminderRepository(ref.watch(apiClientProvider));
});

class CreditReminderRepository {
  final ApiClient _api;

  CreditReminderRepository(this._api);

  Future<Map<String, dynamic>> getOverdueCustomers() async {
    final response = await _api.get(ApiConfig.creditRemindersOverdue);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCustomerOutstanding(String contactId) async {
    final response =
        await _api.get(ApiConfig.creditReminderOutstanding(contactId));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getReminderText(String contactId) async {
    final response =
        await _api.get(ApiConfig.creditReminderText(contactId));
    return response.data as Map<String, dynamic>;
  }

  Future<void> markReminderSent(String contactId, {String channel = 'WHATSAPP'}) async {
    await _api.post(
      ApiConfig.creditReminderMarkSent(contactId),
      data: {'channel': channel},
    );
  }
}
