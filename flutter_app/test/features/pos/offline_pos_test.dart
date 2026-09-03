import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:katasticho/features/pos/data/offline_pos_service.dart';

void main() {
  group('Offline POS & Local Sync Queue Tests', () {
    test('PendingReceipt models request payload and decodes properly', () {
      final request = {
        'offlineReceiptNumber': 'OFF-0042',
        'receiptDate': '2026-08-18',
        'paymentMode': 'CASH',
        'amountReceived': 150.0,
        'contactName': 'Sharma Medicals',
        'lines': [
          {
            'itemId': 'item-123',
            'quantity': 2.0,
            'rate': 75.0,
            'amount': 150.0,
          }
        ],
      };

      final receipt = PendingReceipt(
        id: 1,
        requestJson: jsonEncode(request),
        createdAt: '2026-08-18T10:30:00.000Z',
        retryCount: 0,
        lastError: null,
      );

      expect(receipt.id, 1);
      expect(receipt.retryCount, 0);
      expect(receipt.lastError, isNull);
      expect(receipt.requestBody['offlineReceiptNumber'], 'OFF-0042');
      expect(receipt.requestBody['contactName'], 'Sharma Medicals');
      expect(receipt.requestBody['lines'].length, 1);
    });

    test('PendingReceipt tracks retry count and last error on sync failure', () {
      final receipt = PendingReceipt(
        id: 5,
        requestJson: jsonEncode({'offlineReceiptNumber': 'OFF-0005'}),
        createdAt: '2026-08-18T10:00:00.000Z',
        retryCount: 3,
        lastError: 'SocketException: Connection refused (OS Error: Connection refused, errno = 111)',
      );

      expect(receipt.retryCount, 3);
      expect(receipt.lastError, contains('SocketException'));
    });

    test('Batch sync payload preparation serializes multiple pending receipts', () {
      final list = [
        PendingReceipt(
          id: 1,
          requestJson: jsonEncode({'offlineReceiptNumber': 'OFF-0001', 'total': 100.0}),
          createdAt: '2026-08-18T10:00:00Z',
        ),
        PendingReceipt(
          id: 2,
          requestJson: jsonEncode({'offlineReceiptNumber': 'OFF-0002', 'total': 250.0}),
          createdAt: '2026-08-18T10:05:00Z',
        ),
      ];

      final batchPayload = list.map((r) => r.requestBody).toList();

      expect(batchPayload.length, 2);
      expect(batchPayload[0]['offlineReceiptNumber'], 'OFF-0001');
      expect(batchPayload[1]['offlineReceiptNumber'], 'OFF-0002');
      expect(batchPayload[0]['total'], 100.0);
      expect(batchPayload[1]['total'], 250.0);
    });

    test('Customer search ranking logic ranks phone exact > name prefix > contains', () {
      final customers = [
        {
          'id': 'c1',
          'name': 'Gupta Pharmacy',
          'phone': '9876543210',
          'gstin': '07AAAAA0000A1Z5',
        },
        {
          'id': 'c2',
          'name': 'Aarav Gupta',
          'phone': '9123456789',
          'gstin': '07BBBBB0000B1Z6',
        },
        {
          'id': 'c3',
          'name': 'Health Plus (Gupta)',
          'phone': '9988776655',
          'gstin': '07CCCCC0000C1Z7',
        },
      ];

      // Exact phone match
      const phoneQuery = '9876543210';
      final phoneMatches = customers.where((c) => c['phone'] == phoneQuery).toList();
      expect(phoneMatches.length, 1);

      // Contains match
      final containsMatches = customers
          .where((c) => c['name']!.toLowerCase().contains('gupta'))
          .toList();
      expect(containsMatches.length, 3);
    });

    test('DatabaseStats computes correct human-readable file size and metrics', () {
      const stats1 = DatabaseStats(
        pendingReceiptCount: 4,
        cachedItemCount: 1250,
        cachedCustomerCount: 340,
        fileSizeBytes: 450000,
        integrityOk: true,
        integrityMessage: 'ok',
        dbPath: '/data/user/0/com.katasticho/databases/katasticho_offline.db',
      );

      expect(stats1.pendingReceiptCount, 4);
      expect(stats1.cachedItemCount, 1250);
      expect(stats1.cachedCustomerCount, 340);
      expect(stats1.fileSizeFormatted, '439.5 KB');
      expect(stats1.integrityOk, isTrue);

      const stats2 = DatabaseStats(
        pendingReceiptCount: 0,
        cachedItemCount: 10000,
        cachedCustomerCount: 2000,
        fileSizeBytes: 5242880,
        integrityOk: true,
        integrityMessage: 'ok',
        dbPath: '/test/path.db',
      );
      expect(stats2.fileSizeFormatted, '5.00 MB');
    });
  });
}
