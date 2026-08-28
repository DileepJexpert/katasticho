import 'package:flutter_test/flutter_test.dart';
import 'package:katasticho/features/job_work/data/job_work_models.dart';

void main() {
  group('JobWorkOrderModel Tests', () {
    test('deserializes complete job work order JSON correctly', () {
      final json = {
        'id': 'jwo_001',
        'orderNumber': 'JWO-2026-001',
        'jobWorkerId': 'worker_123',
        'jobWorkerName': 'Precision Coating & Packaging Works',
        'jobWorkerGstin': '27AABCP1234F1Z9',
        'orderDate': '2026-08-18',
        'expectedReturnDate': '2026-09-18',
        'status': 'ISSUED',
        'processDescription': 'Film Coating & Blister Packing',
        'totalIssuedValue': 25000.0,
        'totalReceivedValue': 0.0,
        'notes': 'Urgent export order batch',
        'issueLines': [
          {
            'id': 'line_001',
            'jobWorkOrderId': 'jwo_001',
            'challanNumber': 'CH45-2026-001',
            'challanDate': '2026-08-18',
            'itemId': 'item_raw_1',
            'itemName': 'Uncoated Paracetamol Granules',
            'hsnCode': '30049099',
            'uom': 'KG',
            'issuedQuantity': 100.0,
            'returnedQuantity': 0.0,
            'pendingQuantity': 100.0,
            'unitRate': 250.0,
            'taxableValue': 25000.0,
            'gstRate': 18.0,
            'natureOfProcessing': 'Film Coating',
          }
        ],
        'receiptLines': [],
      };

      final model = JobWorkOrderModel.fromJson(json);

      expect(model.id, equals('jwo_001'));
      expect(model.orderNumber, equals('JWO-2026-001'));
      expect(model.jobWorkerName, equals('Precision Coating & Packaging Works'));
      expect(model.jobWorkerGstin, equals('27AABCP1234F1Z9'));
      expect(model.status, equals('ISSUED'));
      expect(model.totalIssuedValue, equals(25000.0));
      expect(model.issueLines.length, equals(1));
      expect(model.issueLines.first.challanNumber, equals('CH45-2026-001'));
      expect(model.issueLines.first.pendingQuantity, equals(100.0));
    });
  });

  group('Itc04SummaryModel Tests', () {
    test('deserializes ITC-04 statutory report JSON correctly', () {
      final json = {
        'quarter': 'Q1',
        'year': 2026,
        'totalChallans': 5,
        'totalIssuedValue': 125000.0,
        'totalReturnedValue': 80000.0,
        'pendingValue': 45000.0,
        'table4InputsSent': [
          {
            'challanNumber': 'CH45-101',
            'challanDate': '2026-04-15',
            'jobWorkerName': 'Fine Chemical Processors',
            'jobWorkerGstin': '27AABCP5678F1Z2',
            'itemName': 'Raw Chemical Salt A',
            'hsnCode': '29332990',
            'uom': 'KG',
            'quantity': 500.0,
            'taxableValue': 75000.0,
            'natureOfProcessing': 'Purification',
            'recordType': 'SENT_INPUTS',
          }
        ],
        'table5AReceivedBack': [
          {
            'challanNumber': 'INW-501',
            'challanDate': '2026-05-10',
            'jobWorkerName': 'Fine Chemical Processors',
            'jobWorkerGstin': '27AABCP5678F1Z2',
            'itemName': 'Purified Chemical Salt A',
            'hsnCode': '29332990',
            'uom': 'KG',
            'quantity': 490.0,
            'taxableValue': 5000.0,
            'natureOfProcessing': 'Received Back',
            'recordType': 'RECEIVED_BACK',
          }
        ],
      };

      final report = Itc04SummaryModel.fromJson(json);

      expect(report.quarter, equals('Q1'));
      expect(report.year, equals(2026));
      expect(report.totalChallans, equals(5));
      expect(report.totalIssuedValue, equals(125000.0));
      expect(report.totalReturnedValue, equals(80000.0));
      expect(report.pendingValue, equals(45000.0));
      expect(report.table4InputsSent.length, equals(1));
      expect(report.table4InputsSent.first.challanNumber, equals('CH45-101'));
      expect(report.table5AReceivedBack.length, equals(1));
      expect(report.table5AReceivedBack.first.recordType, equals('RECEIVED_BACK'));
    });
  });

  group('Job Work Request Payloads', () {
    test('serializes CreateJobWorkRequest correctly', () {
      final req = CreateJobWorkRequest(
        jobWorkerId: 'worker_123',
        orderDate: '2026-08-18',
        expectedReturnDate: '2026-09-18',
        processDescription: 'Coating',
        notes: 'Priority',
        issueLines: [
          {'itemId': 'item_1', 'issuedQuantity': 100.0}
        ],
      );

      final map = req.toJson();

      expect(map['jobWorkerId'], equals('worker_123'));
      expect(map['orderDate'], equals('2026-08-18'));
      expect(map['processDescription'], equals('Coating'));
      expect((map['issueLines'] as List).length, equals(1));
    });

    test('serializes ReceiveJobWorkRequest correctly', () {
      const req = ReceiveJobWorkRequest(
        inwardChallanNumber: 'INW-009',
        receiptDate: '2026-08-25',
        finishedItemId: 'fin_item_1',
        receivedQuantity: 98.0,
        consumedRawItemId: 'raw_item_1',
        consumedQuantity: 100.0,
        scrapQuantity: 2.0,
        jobWorkCharges: 3500.0,
        notes: 'Passed quality QC',
      );

      final map = req.toJson();

      expect(map['inwardChallanNumber'], equals('INW-009'));
      expect(map['finishedItemId'], equals('fin_item_1'));
      expect(map['receivedQuantity'], equals(98.0));
      expect(map['consumedQuantity'], equals(100.0));
      expect(map['scrapQuantity'], equals(2.0));
      expect(map['jobWorkCharges'], equals(3500.0));
    });
  });
}
