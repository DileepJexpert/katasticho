import 'package:flutter_test/flutter_test.dart';
import 'package:katasticho/features/gst/data/gstr2b_reconciliation_model.dart';

void main() {
  group('GSTR-2B Reconciliation Model Tests', () {
    test('Gstr2bEntryModel parses correctly from json', () {
      final json = {
        'id': 'entry-123',
        'returnPeriod': '2026-07',
        'supplierGstin': '29ABCDE1234F1Z5',
        'supplierName': 'Acme Pharma Ltd',
        'invoiceNumber': 'INV-9901',
        'invoiceDate': '2026-07-15',
        'invoiceValue': 11800.0,
        'taxableValue': 10000.0,
        'igst': 1800.0,
        'cgst': 0.0,
        'sgst': 0.0,
        'cess': 0.0,
        'matchStatus': 'MATCHED',
        'matchNote': 'Matched Bill PB-2026-001',
      };

      final entry = Gstr2bEntryModel.fromJson(json);

      expect(entry.id, 'entry-123');
      expect(entry.supplierGstin, '29ABCDE1234F1Z5');
      expect(entry.supplierName, 'Acme Pharma Ltd');
      expect(entry.invoiceNumber, 'INV-9901');
      expect(entry.invoiceValue, 11800.0);
      expect(entry.totalTax, 1800.0);
      expect(entry.matchStatus, 'MATCHED');
    });

    test('SupplierNotFiledModel parses correctly from json', () {
      final json = {
        'billId': 'bill-456',
        'billNumber': 'BILL-2026-088',
        'vendorBillNumber': 'VB-771',
        'vendorName': 'Sun Healthcare Dist',
        'vendorGstin': '27XYZAB9876C1Z2',
        'billDate': '2026-07-20',
        'totalAmount': 50000.0,
        'itc': 9000.0,
        'phone': '9876543210',
        'email': 'accounts@sunhealthcare.com',
      };

      final model = SupplierNotFiledModel.fromJson(json);

      expect(model.billId, 'bill-456');
      expect(model.vendorBillNumber, 'VB-771');
      expect(model.vendorName, 'Sun Healthcare Dist');
      expect(model.totalAmount, 50000.0);
      expect(model.itc, 9000.0);
      expect(model.phone, '9876543210');
      expect(model.email, 'accounts@sunhealthcare.com');
    });

    test('Gstr2bSummaryModel parses summary breakdown and at-risk list', () {
      final json = {
        'period': '2026-07',
        'totalEntries': 25,
        'matched': 20,
        'valueMismatch': 2,
        'notInBooks': 3,
        'matchedItc': 150000.0,
        'mismatchItc': 12000.0,
        'missingItc': 18000.0,
        'itcAtRisk': 24000.0,
        'supplierNotFiled': [
          {
            'billId': 'b1',
            'billNumber': 'PB-01',
            'vendorName': 'Vendor A',
            'vendorGstin': '29AAAAA0000A1Z5',
            'totalAmount': 20000.0,
            'itc': 3600.0,
          }
        ],
      };

      final summary = Gstr2bSummaryModel.fromJson(json);

      expect(summary.period, '2026-07');
      expect(summary.totalEntries, 25);
      expect(summary.matched, 20);
      expect(summary.valueMismatch, 2);
      expect(summary.notInBooks, 3);
      expect(summary.matchedItc, 150000.0);
      expect(summary.itcAtRisk, 24000.0);
      expect(summary.supplierNotFiled.length, 1);
      expect(summary.supplierNotFiled.first.vendorName, 'Vendor A');
    });

    test('VendorNudgeHelper formats clear and polite message copy', () {
      final msg = VendorNudgeHelper.buildNudgeMessage(
        vendorName: 'Apex Chem & Pharma',
        invoiceNo: 'APEX/2026/410',
        invoiceDate: '2026-07-18',
        invoiceAmount: 25000.0,
        itcAmount: 4500.0,
        returnPeriod: '2026-07',
        orgName: 'MediStore ERP',
      );

      expect(msg, contains('Dear Apex Chem & Pharma,'));
      expect(msg, contains('Invoice #APEX/2026/410'));
      expect(msg, contains('dated 2026-07-18'));
      expect(msg, contains('25000.00'));
      expect(msg, contains('4500.00'));
      expect(msg, contains('GSTR-2B statement'));
      expect(msg, contains('GSTR-1 / IFF filing'));
    });
  });
}
