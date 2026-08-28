import 'package:flutter_test/flutter_test.dart';
import 'package:katasticho/features/whatsapp/data/whatsapp_models.dart';

void main() {
  group('WhatsAppMessageModel Tests', () {
    test('deserializes complete WhatsApp message JSON correctly', () {
      final json = {
        'id': 'msg_001',
        'recipient': '919876543210',
        'docType': 'INVOICE',
        'docId': 'inv_123',
        'templateName': 'invoice_document',
        'status': 'SENT',
        'provider': 'META',
        'providerMessageId': 'wamid_1098765432',
        'errorMessage': null,
        'sentAt': '2026-08-18T11:00:00Z',
        'direction': 'OUTBOUND',
        'body': 'Here is your invoice PDF from Apex Pharma',
      };

      final model = WhatsAppMessageModel.fromJson(json);

      expect(model.id, equals('msg_001'));
      expect(model.recipient, equals('919876543210'));
      expect(model.docType, equals('INVOICE'));
      expect(model.docId, equals('inv_123'));
      expect(model.status, equals('SENT'));
      expect(model.provider, equals('META'));
      expect(model.providerMessageId, equals('wamid_1098765432'));
      expect(model.direction, equals('OUTBOUND'));
      expect(model.body, equals('Here is your invoice PDF from Apex Pharma'));
    });

    test('deserializes inbound bot message with fallbacks', () {
      final json = {
        'id': 'msg_002',
        'recipient': '919876543210',
        'status': 'RECEIVED',
        'direction': 'INBOUND',
        'body': 'ORDER 10 Crocin 650',
        'createdAt': '2026-08-18T11:05:00Z',
      };

      final model = WhatsAppMessageModel.fromJson(json);

      expect(model.id, equals('msg_002'));
      expect(model.direction, equals('INBOUND'));
      expect(model.status, equals('RECEIVED'));
      expect(model.body, equals('ORDER 10 Crocin 650'));
      expect(model.sentAt, equals('2026-08-18T11:05:00Z'));
      expect(model.docType, equals('DOCUMENT'));
    });
  });

  group('BotReplyModel Tests', () {
    test('deserializes bot reply for Order Creation correctly', () {
      final json = {
        'replyText': '✅ Order Created Successfully! Order Number: SO-2026-001',
        'intent': 'ORDER',
        'actionTaken': 'ORDER_CREATED',
        'status': 'COMPLETED',
        'relatedDocId': 'so_uuid_456',
        'docType': 'SALES_ORDER',
      };

      final model = BotReplyModel.fromJson(json);

      expect(model.intent, equals('ORDER'));
      expect(model.actionTaken, equals('ORDER_CREATED'));
      expect(model.status, equals('COMPLETED'));
      expect(model.relatedDocId, equals('so_uuid_456'));
      expect(model.docType, equals('SALES_ORDER'));
      expect(model.replyText, contains('SO-2026-001'));
    });

    test('deserializes bot reply for Balance Check', () {
      final json = {
        'replyText': '📊 Total Outstanding: ₹15,000.00 across 2 invoices',
        'intent': 'BALANCE',
        'actionTaken': 'BALANCE_FETCHED',
        'status': 'COMPLETED',
      };

      final model = BotReplyModel.fromJson(json);

      expect(model.intent, equals('BALANCE'));
      expect(model.actionTaken, equals('BALANCE_FETCHED'));
      expect(model.relatedDocId, isNull);
    });
  });

  group('WhatsAppSettingsModel Tests', () {
    test('deserializes gateway settings with webhook configuration', () {
      final json = {
        'enabled': true,
        'provider': 'META',
        'phoneNumberId': '10987654321',
        'lang': 'en',
        'autoSendReceipt': true,
        'apiKeySet': true,
        'webhookToken': 'whk_token_789',
        'webhookUrl': '/api/v1/whatsapp/webhook/whk_token_789',
        'verifyToken': 'whk_token_789',
      };

      final model = WhatsAppSettingsModel.fromJson(json);

      expect(model.enabled, isTrue);
      expect(model.provider, equals('META'));
      expect(model.phoneNumberId, equals('10987654321'));
      expect(model.autoSendReceipt, isTrue);
      expect(model.apiKeySet, isTrue);
      expect(model.webhookToken, equals('whk_token_789'));
      expect(model.webhookUrl, equals('/api/v1/whatsapp/webhook/whk_token_789'));
    });
  });

  group('BotSimulationRequestPayload Tests', () {
    test('serializes simulation payload correctly', () {
      const payload = BotSimulationRequestPayload(
        contactId: 'c_101',
        message: 'ORDER 5 Dolo 500',
        fromPhone: '919876543210',
      );

      final map = payload.toJson();

      expect(map['contactId'], equals('c_101'));
      expect(map['message'], equals('ORDER 5 Dolo 500'));
      expect(map['fromPhone'], equals('919876543210'));
    });
  });
}
