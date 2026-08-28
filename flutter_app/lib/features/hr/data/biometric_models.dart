class BiometricDeviceModel {
  final String id;
  final String deviceName;
  final String? deviceIp;
  final int port;
  final String? serialNumber;
  final String protocol;
  final String? location;
  final String status;
  final String? lastSyncAt;
  final String? cloudWebhookToken;

  const BiometricDeviceModel({
    required this.id,
    required this.deviceName,
    this.deviceIp,
    this.port = 4370,
    this.serialNumber,
    this.protocol = 'ZK_TCP',
    this.location,
    this.status = 'ONLINE',
    this.lastSyncAt,
    this.cloudWebhookToken,
  });

  factory BiometricDeviceModel.fromJson(Map<String, dynamic> json) {
    return BiometricDeviceModel(
      id: json['id']?.toString() ?? '',
      deviceName: json['deviceName']?.toString() ?? '',
      deviceIp: json['deviceIp']?.toString(),
      port: (json['port'] as num?)?.toInt() ?? 4370,
      serialNumber: json['serialNumber']?.toString(),
      protocol: json['protocol']?.toString() ?? 'ZK_TCP',
      location: json['location']?.toString(),
      status: json['status']?.toString() ?? 'ONLINE',
      lastSyncAt: json['lastSyncAt']?.toString(),
      cloudWebhookToken: json['cloudWebhookToken']?.toString(),
    );
  }
}

class BiometricPunchLogModel {
  final String id;
  final String? deviceId;
  final String deviceName;
  final String? employeeId;
  final String employeeName;
  final String employeeCode;
  final String biometricPin;
  final String punchTime;
  final String punchType;
  final String verifyMode;
  final String syncStatus;

  const BiometricPunchLogModel({
    required this.id,
    this.deviceId,
    required this.deviceName,
    this.employeeId,
    required this.employeeName,
    required this.employeeCode,
    required this.biometricPin,
    required this.punchTime,
    required this.punchType,
    required this.verifyMode,
    required this.syncStatus,
  });

  factory BiometricPunchLogModel.fromJson(Map<String, dynamic> json) {
    return BiometricPunchLogModel(
      id: json['id']?.toString() ?? '',
      deviceId: json['deviceId']?.toString(),
      deviceName: json['deviceName']?.toString() ?? 'Hardware Clock',
      employeeId: json['employeeId']?.toString(),
      employeeName: json['employeeName']?.toString() ?? 'Unknown Employee',
      employeeCode: json['employeeCode']?.toString() ?? '-',
      biometricPin: json['biometricPin']?.toString() ?? '',
      punchTime: json['punchTime']?.toString() ?? '',
      punchType: json['punchType']?.toString() ?? 'CHECK_IN',
      verifyMode: json['verifyMode']?.toString() ?? 'FINGERPRINT',
      syncStatus: json['syncStatus']?.toString() ?? 'PROCESSED',
    );
  }
}

class RegisterBiometricDeviceRequest {
  final String deviceName;
  final String? deviceIp;
  final int port;
  final String? serialNumber;
  final String protocol;
  final String? location;

  const RegisterBiometricDeviceRequest({
    required this.deviceName,
    this.deviceIp,
    this.port = 4370,
    this.serialNumber,
    this.protocol = 'ZK_TCP',
    this.location,
  });

  Map<String, dynamic> toJson() => {
        'deviceName': deviceName,
        if (deviceIp != null) 'deviceIp': deviceIp,
        'port': port,
        if (serialNumber != null) 'serialNumber': serialNumber,
        'protocol': protocol,
        if (location != null) 'location': location,
      };
}

class SimulatePunchRequestPayload {
  final String? deviceId;
  final String? employeeId;
  final String? biometricPin;
  final String? punchType;
  final String? verifyMode;

  const SimulatePunchRequestPayload({
    this.deviceId,
    this.employeeId,
    this.biometricPin,
    this.punchType,
    this.verifyMode,
  });

  Map<String, dynamic> toJson() => {
        if (deviceId != null) 'deviceId': deviceId,
        if (employeeId != null) 'employeeId': employeeId,
        if (biometricPin != null) 'biometricPin': biometricPin,
        if (punchType != null) 'punchType': punchType,
        if (verifyMode != null) 'verifyMode': verifyMode,
      };
}
