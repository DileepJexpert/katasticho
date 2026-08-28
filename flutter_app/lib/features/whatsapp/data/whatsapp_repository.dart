import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import 'whatsapp_models.dart';

final whatsappRepositoryProvider = Provider<WhatsAppRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return WhatsAppRepository(client);
});

final whatsappMessagesProvider =
    FutureProvider.autoDispose<List<WhatsAppMessageModel>>((ref) async {
  final repo = ref.watch(whatsappRepositoryProvider);
  return repo.fetchMessages();
});

final whatsappSettingsProvider =
    FutureProvider.autoDispose<WhatsAppSettingsModel>((ref) async {
  final repo = ref.watch(whatsappRepositoryProvider);
  return repo.fetchSettings();
});

class WhatsAppRepository {
  final ApiClient _client;

  WhatsAppRepository(this._client);

  Future<List<WhatsAppMessageModel>> fetchMessages() async {
    final response = await _client.get(ApiConfig.whatsappMessages);
    final data = response.data['data'] as List? ?? [];
    return data
        .map((m) => WhatsAppMessageModel.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<BotReplyModel> simulateBot(BotSimulationRequestPayload req) async {
    final response = await _client.post(
      ApiConfig.whatsappSimulateBot,
      data: req.toJson(),
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return BotReplyModel.fromJson(data);
  }

  Future<WhatsAppSettingsModel> fetchSettings() async {
    final response = await _client.get(ApiConfig.whatsappSettings);
    final data = response.data['data'] as Map<String, dynamic>;
    return WhatsAppSettingsModel.fromJson(data);
  }

  Future<WhatsAppSettingsModel> updateSettings(Map<String, String> body) async {
    final response = await _client.put(
      ApiConfig.whatsappSettings,
      data: body,
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return WhatsAppSettingsModel.fromJson(data);
  }

  Future<WhatsAppMessageModel> sendReminder(String contactId) async {
    final response = await _client.post(ApiConfig.whatsappSendReminder(contactId));
    final data = response.data['data'] as Map<String, dynamic>;
    return WhatsAppMessageModel.fromJson(data);
  }

  Future<WhatsAppMessageModel> sendStatement(String contactId) async {
    final response = await _client.post(ApiConfig.whatsappSendStatement(contactId));
    final data = response.data['data'] as Map<String, dynamic>;
    return WhatsAppMessageModel.fromJson(data);
  }

  Future<WhatsAppMessageModel> sendInvoice(String invoiceId) async {
    final response = await _client.post(ApiConfig.whatsappSendInvoice(invoiceId));
    final data = response.data['data'] as Map<String, dynamic>;
    return WhatsAppMessageModel.fromJson(data);
  }

  Future<WhatsAppMessageModel> sendReceipt(String receiptId) async {
    final response = await _client.post(ApiConfig.whatsappSendReceipt(receiptId));
    final data = response.data['data'] as Map<String, dynamic>;
    return WhatsAppMessageModel.fromJson(data);
  }
}
