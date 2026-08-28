import 'package:flutter_test/flutter_test.dart';
import 'package:katasticho/features/banking/data/payout_models.dart';

void main() {
  group('PayoutDisbursementModel Tests', () {
    test('deserializes complete payout response correctly', () {
      final json = {
        'id': 'pay_disb_001',
        'provider': 'RAZORPAYX',
        'providerPayoutId': 'pout_1234567890',
        'utr': 'CMS123456789012',
        'status': 'PROCESSED',
        'contactId': 'cont_999',
        'contactName': 'Acme Pharma Distributors',
        'amount': 45000.50,
        'currency': 'INR',
        'payoutMode': 'IMPS',
        'beneficiaryName': 'Acme Pharma Distributors Pvt Ltd',
        'accountNumberMasked': 'XXXXXXXX1234',
        'ifscCode': 'HDFC0001234',
        'vpa': null,
        'vendorPaymentId': 'vp_888',
        'failureReason': null,
        'createdAt': '2026-08-18T10:30:00Z',
      };

      final model = PayoutDisbursementModel.fromJson(json);

      expect(model.id, equals('pay_disb_001'));
      expect(model.provider, equals('RAZORPAYX'));
      expect(model.providerPayoutId, equals('pout_1234567890'));
      expect(model.utr, equals('CMS123456789012'));
      expect(model.status, equals('PROCESSED'));
      expect(model.contactId, equals('cont_999'));
      expect(model.contactName, equals('Acme Pharma Distributors'));
      expect(model.amount, equals(45000.50));
      expect(model.payoutMode, equals('IMPS'));
      expect(model.accountNumberMasked, equals('XXXXXXXX1234'));
      expect(model.ifscCode, equals('HDFC0001234'));
      expect(model.vendorPaymentId, equals('vp_888'));
      expect(model.createdAt, equals('2026-08-18T10:30:00Z'));
    });

    test('deserializes UPI payout response correctly', () {
      final json = {
        'id': 'pay_disb_002',
        'provider': 'RAZORPAYX',
        'providerPayoutId': 'pout_9876543210',
        'utr': 'UPI9876543210',
        'status': 'PROCESSED',
        'contactId': 'cont_777',
        'contactName': 'Dr. Sharma Clinic',
        'amount': 12500.00,
        'currency': 'INR',
        'payoutMode': 'UPI',
        'vpa': 'sharma@okhdfcbank',
      };

      final model = PayoutDisbursementModel.fromJson(json);

      expect(model.id, equals('pay_disb_002'));
      expect(model.payoutMode, equals('UPI'));
      expect(model.vpa, equals('sharma@okhdfcbank'));
      expect(model.accountNumberMasked, isNull);
      expect(model.amount, equals(12500.00));
    });

    test('handles fallback defaults on minimal payload', () {
      final json = {
        'id': 'pay_disb_003',
        'status': 'INITIATED',
        'contactId': 'cont_1',
      };

      final model = PayoutDisbursementModel.fromJson(json);

      expect(model.id, equals('pay_disb_003'));
      expect(model.provider, equals('RAZORPAYX'));
      expect(model.amount, equals(0.0));
      expect(model.currency, equals('INR'));
      expect(model.payoutMode, equals('IMPS'));
      expect(model.contactName, equals('Vendor'));
    });
  });

  group('PayoutDisbursementRequestPayload Tests', () {
    test('serializes Bank Transfer request payload with bill allocations', () {
      const payload = PayoutDisbursementRequestPayload(
        contactId: 'c-101',
        amount: 25000.0,
        paidThroughAccountId: 'acc-501',
        payoutMode: 'NEFT',
        beneficiaryName: 'Sun Pharma Logistics',
        accountNumber: '912345678901',
        ifscCode: 'ICIC0000001',
        narration: 'Payment for PO-2026-08',
        billAllocations: [
          BillAllocationPayload(billId: 'bill-01', amountApplied: 15000.0),
          BillAllocationPayload(billId: 'bill-02', amountApplied: 10000.0),
        ],
      );

      final map = payload.toJson();

      expect(map['contactId'], equals('c-101'));
      expect(map['amount'], equals(25000.0));
      expect(map['paidThroughAccountId'], equals('acc-501'));
      expect(map['payoutMode'], equals('NEFT'));
      expect(map['beneficiaryName'], equals('Sun Pharma Logistics'));
      expect(map['accountNumber'], equals('912345678901'));
      expect(map['ifscCode'], equals('ICIC0000001'));
      expect(map['narration'], equals('Payment for PO-2026-08'));
      expect(map['vpa'], isNull);

      final allocations = map['billAllocations'] as List;
      expect(allocations.length, equals(2));
      expect(allocations[0]['billId'], equals('bill-01'));
      expect(allocations[0]['amountApplied'], equals(15000.0));
      expect(allocations[1]['billId'], equals('bill-02'));
      expect(allocations[1]['amountApplied'], equals(10000.0));
    });

    test('serializes UPI disbursement request payload', () {
      const payload = PayoutDisbursementRequestPayload(
        contactId: 'c-102',
        amount: 5000.0,
        paidThroughAccountId: 'acc-502',
        payoutMode: 'UPI',
        beneficiaryName: 'Apollo Delivery Partner',
        vpa: 'apollo@upi',
      );

      final map = payload.toJson();

      expect(map['contactId'], equals('c-102'));
      expect(map['amount'], equals(5000.0));
      expect(map['payoutMode'], equals('UPI'));
      expect(map['vpa'], equals('apollo@upi'));
      expect(map['accountNumber'], isNull);
      expect(map['ifscCode'], isNull);
      expect(map.containsKey('billAllocations'), isFalse);
    });
  });
}
