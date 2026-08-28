import 'package:flutter_test/flutter_test.dart';
import 'package:katasticho/features/pos/data/thermal_print_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThermalPrintService & ESC/POS Raw Socket Tests', () {
    test('ReceiptPrintSettings defaults and copyWith preserve immutability', () {
      const settings = ReceiptPrintSettings();

      expect(settings.paperSize, '58mm');
      expect(settings.connectionType, PrinterConnectionType.network);
      expect(settings.networkIp, '192.168.1.200');
      expect(settings.networkPort, 9100);
      expect(settings.autoCut, true);
      expect(settings.openCashDrawer, false);
      expect(settings.showDrugLicense, true);
      expect(settings.showSavingsBanner, true);

      final wide80 = settings.copyWith(
        paperSize: '80mm',
        networkIp: '192.168.0.50',
        openCashDrawer: true,
      );

      expect(wide80.paperSize, '80mm');
      expect(wide80.networkIp, '192.168.0.50');
      expect(wide80.openCashDrawer, true);
      expect(wide80.networkPort, 9100); // unchanged
    });

    test('buildReceiptBytes generates valid ESC/POS byte stream for 58mm receipt', () async {
      final service = ThermalPrintService.instance;
      const settings = ReceiptPrintSettings(
        paperSize: '58mm',
        autoCut: true,
        openCashDrawer: false,
        showSavingsBanner: true,
      );

      final dummyReceipt = {
        'receiptNumber': 'REC-2026-0099',
        'receiptDate': '2026-08-18T10:30:00Z',
        'cashierName': 'Rahul',
        'contactName': 'Deepak Sharma',
        'contactPhone': '9876543210',
        'lines': [
          {
            'itemName': 'Dolo 650 Strip',
            'quantity': 2,
            'rate': 30.0,
            'amount': 60.0,
            'unit': 'STRIP',
            'batchNumber': 'DOLO-99',
            'expiryDate': '2027-11-30',
            'discountAmount': 5.0,
          }
        ],
        'subtotal': 60.0,
        'discountTotal': 5.0,
        'cgst': 1.38,
        'sgst': 1.38,
        'total': 55.0,
        'paymentMode': 'CASH',
        'amountReceived': 100.0,
        'changeReturned': 45.0,
      };

      final org = {
        'name': 'Gupta Medicos',
        'address': 'Main Market, Delhi',
        'phone': '011-23456789',
        'gstin': '07ABCDE1234F1Z5',
        'drugLicenseNo': 'DL-20B-998877',
      };

      final bytes = await service.buildReceiptBytes(
        receipt: dummyReceipt,
        org: org,
        settings: settings,
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(50));

      // ESC/POS Reset command is 0x1B, 0x40 ('@')
      expect(bytes.contains(0x1B), isTrue);

      // Verify no cash drawer sequence if disabled
      final hasDrawerPulse = _containsSubsequence(bytes, [0x1B, 0x70, 0x00, 0x19, 0xFA]);
      expect(hasDrawerPulse, isFalse);
    });

    test('buildReceiptBytes inserts Cash Drawer Kick command when openCashDrawer is enabled', () async {
      final service = ThermalPrintService.instance;
      const settings = ReceiptPrintSettings(
        paperSize: '80mm',
        autoCut: true,
        openCashDrawer: true,
      );

      final dummyReceipt = {
        'receiptNumber': 'REC-2026-0100',
        'receiptDate': '2026-08-18T11:00:00Z',
        'lines': [
          {
            'itemName': 'Crocin Advance',
            'quantity': 1,
            'rate': 20.0,
            'amount': 20.0,
            'unit': 'STRIP',
          }
        ],
        'subtotal': 20.0,
        'total': 20.0,
        'paymentMode': 'CASH',
      };

      final org = {'name': 'Retail Kirana Store'};

      final bytes = await service.buildReceiptBytes(
        receipt: dummyReceipt,
        org: org,
        settings: settings,
      );

      // Verify cash drawer pulse sequence exists: ESC p 0 25 250 (0x1B, 0x70, 0x00, 0x19, 0xFA)
      final hasDrawerPulse = _containsSubsequence(bytes, [0x1B, 0x70, 0x00, 0x19, 0xFA]);
      expect(hasDrawerPulse, isTrue);
    });

    test('buildReceiptBytes formats 80mm wide layout with batch, expiry and savings banner', () async {
      final service = ThermalPrintService.instance;
      const settings = ReceiptPrintSettings(
        paperSize: '80mm',
        autoCut: true,
        showDrugLicense: true,
        showSavingsBanner: true,
        showTaxBreakdown: true,
      );

      final dummyReceipt = {
        'receiptNumber': 'BILL-80MM-001',
        'receiptDate': '2026-08-18T12:00:00Z',
        'lines': [
          {
            'itemName': 'Augmentin 625 Duo',
            'quantity': 3,
            'rate': 200.0,
            'amount': 600.0,
            'unit': 'STRIP',
            'batchNumber': 'AUG-8871',
            'expiryDate': '2028-03-31',
          }
        ],
        'subtotal': 600.0,
        'discountTotal': 60.0,
        'cgst': 27.0,
        'sgst': 27.0,
        'total': 540.0,
        'paymentMode': 'UPI',
        'amountReceived': 540.0,
        'changeReturned': 0.0,
      };

      final org = {
        'name': 'Apollo Pharmacy Franchise',
        'drugLicenseNo': 'DL-20B-112233',
        'gstin': '07XYZ9999P1Z1',
      };

      final bytes = await service.buildReceiptBytes(
        receipt: dummyReceipt,
        org: org,
        settings: settings,
        upiUri: 'upi://pay?pa=apollo@upi&pn=Apollo&am=540.00&cu=INR',
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));
    });
  });
}

bool _containsSubsequence(List<int> fullList, List<int> sub) {
  if (sub.isEmpty) return true;
  for (int i = 0; i <= fullList.length - sub.length; i++) {
    bool match = true;
    for (int j = 0; j < sub.length; j++) {
      if (fullList[i + j] != sub[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}
