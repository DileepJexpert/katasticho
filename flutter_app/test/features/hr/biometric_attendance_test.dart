import 'package:flutter_test/flutter_test.dart';
import 'package:katasticho/features/hr/data/biometric_models.dart';

void main() {
  group('BiometricDeviceModel Tests', () {
    test('deserializes complete device JSON correctly', () {
      final json = {
        'id': 'dev_001',
        'deviceName': 'Main Gate Turnstile',
        'deviceIp': '192.168.1.201',
        'port': 4370,
        'serialNumber': 'ZK987654321',
        'protocol': 'ZK_TCP',
        'location': 'Gate 1',
        'status': 'ONLINE',
        'lastSyncAt': '2026-08-18T10:00:00Z',
        'cloudWebhookToken': 'bio_token_abc123',
      };

      final model = BiometricDeviceModel.fromJson(json);

      expect(model.id, equals('dev_001'));
      expect(model.deviceName, equals('Main Gate Turnstile'));
      expect(model.deviceIp, equals('192.168.1.201'));
      expect(model.port, equals(4370));
      expect(model.serialNumber, equals('ZK987654321'));
      expect(model.protocol, equals('ZK_TCP'));
      expect(model.location, equals('Gate 1'));
      expect(model.status, equals('ONLINE'));
      expect(model.cloudWebhookToken, equals('bio_token_abc123'));
    });
  });

  group('BiometricPunchLogModel Tests', () {
    test('deserializes punch log with employee mapping', () {
      final json = {
        'id': 'log_001',
        'deviceId': 'dev_001',
        'deviceName': 'Main Gate Turnstile',
        'employeeId': 'emp_123',
        'employeeName': 'Rajesh Kumar',
        'employeeCode': 'EMP-001',
        'biometricPin': '101',
        'punchTime': '2026-08-18T09:00:00Z',
        'punchType': 'CHECK_IN',
        'verifyMode': 'FINGERPRINT',
        'syncStatus': 'PROCESSED',
      };

      final model = BiometricPunchLogModel.fromJson(json);

      expect(model.id, equals('log_001'));
      expect(model.deviceName, equals('Main Gate Turnstile'));
      expect(model.employeeName, equals('Rajesh Kumar'));
      expect(model.employeeCode, equals('EMP-001'));
      expect(model.biometricPin, equals('101'));
      expect(model.punchType, equals('CHECK_IN'));
      expect(model.verifyMode, equals('FINGERPRINT'));
      expect(model.syncStatus, equals('PROCESSED'));
    });

    test('deserializes unmatched punch log with fallbacks', () {
      final json = {
        'id': 'log_002',
        'biometricPin': '999',
        'punchTime': '2026-08-18T09:05:00Z',
      };

      final model = BiometricPunchLogModel.fromJson(json);

      expect(model.id, equals('log_002'));
      expect(model.biometricPin, equals('999'));
      expect(model.employeeName, equals('Unknown Employee'));
      expect(model.employeeCode, equals('-'));
      expect(model.punchType, equals('CHECK_IN'));
      expect(model.syncStatus, equals('PROCESSED'));
    });
  });

  group('Biometric Request Payload Tests', () {
    test('serializes RegisterBiometricDeviceRequest correctly', () {
      const req = RegisterBiometricDeviceRequest(
        deviceName: 'Warehouse Clock',
        deviceIp: '192.168.1.205',
        port: 4370,
        serialNumber: 'SN_WH_01',
        protocol: 'ADMS_HTTP',
        location: 'Warehouse B',
      );

      final map = req.toJson();

      expect(map['deviceName'], equals('Warehouse Clock'));
      expect(map['deviceIp'], equals('192.168.1.205'));
      expect(map['port'], equals(4370));
      expect(map['serialNumber'], equals('SN_WH_01'));
      expect(map['protocol'], equals('ADMS_HTTP'));
      expect(map['location'], equals('Warehouse B'));
    });

    test('serializes SimulatePunchRequestPayload correctly', () {
      const req = SimulatePunchRequestPayload(
        deviceId: 'dev_001',
        employeeId: 'emp_123',
        biometricPin: '101',
        punchType: 'CHECK_IN',
        verifyMode: 'FACE',
      );

      final map = req.toJson();

      expect(map['deviceId'], equals('dev_001'));
      expect(map['employeeId'], equals('emp_123'));
      expect(map['biometricPin'], equals('101'));
      expect(map['punchType'], equals('CHECK_IN'));
      expect(map['verifyMode'], equals('FACE'));
    });
  });
}
