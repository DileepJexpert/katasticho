import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final stockTransitRepositoryProvider = Provider<StockTransitRepository>((ref) {
  return StockTransitRepository(ref.watch(apiClientProvider));
});

class TransitEventDto {
  final String id;
  final String eventType;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final String? eventNotes;
  final String recordedAt;

  const TransitEventDto({
    required this.id,
    required this.eventType,
    this.latitude,
    this.longitude,
    this.locationName,
    this.eventNotes,
    required this.recordedAt,
  });

  factory TransitEventDto.fromJson(Map<String, dynamic> json) {
    return TransitEventDto(
      id: json['id'] as String,
      eventType: json['eventType'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationName: json['locationName'] as String?,
      eventNotes: json['eventNotes'] as String?,
      recordedAt: json['recordedAt'] as String,
    );
  }
}

class TransferOrderDispatchDto {
  final String id;
  final String orgId;
  final String transferOrderId;
  final String vehicleNumber;
  final String driverName;
  final String? driverPhone;
  final String dispatchedAt;
  final String? expectedDeliveryAt;
  final String? deliveredAt;
  final String status;
  final double? latitude;
  final double? longitude;
  final String? lastLocationName;
  final String? lastPingAt;
  final String createdAt;
  final List<TransitEventDto> events;

  const TransferOrderDispatchDto({
    required this.id,
    required this.orgId,
    required this.transferOrderId,
    required this.vehicleNumber,
    required this.driverName,
    this.driverPhone,
    required this.dispatchedAt,
    this.expectedDeliveryAt,
    this.deliveredAt,
    required this.status,
    this.latitude,
    this.longitude,
    this.lastLocationName,
    this.lastPingAt,
    required this.createdAt,
    required this.events,
  });

  factory TransferOrderDispatchDto.fromJson(Map<String, dynamic> json) {
    return TransferOrderDispatchDto(
      id: json['id'] as String,
      orgId: json['orgId'] as String,
      transferOrderId: json['transferOrderId'] as String,
      vehicleNumber: json['vehicleNumber'] as String,
      driverName: json['driverName'] as String,
      driverPhone: json['driverPhone'] as String?,
      dispatchedAt: json['dispatchedAt'] as String,
      expectedDeliveryAt: json['expectedDeliveryAt'] as String?,
      deliveredAt: json['deliveredAt'] as String?,
      status: json['status'] as String? ?? 'DISPATCHED',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      lastLocationName: json['lastLocationName'] as String?,
      lastPingAt: json['lastPingAt'] as String?,
      createdAt: json['createdAt'] as String,
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => TransitEventDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class StockTransitRepository {
  final ApiClient _api;
  StockTransitRepository(this._api);

  Future<List<TransferOrderDispatchDto>> listDispatches({String? status}) async {
    final res = await _api.get(
      ApiConfig.stockTransferTransit,
      queryParameters: {
        if (status != null && status != 'ALL') 'status': status,
      },
    );
    final list = (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return list.map((e) => TransferOrderDispatchDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TransferOrderDispatchDto> getDispatch(String id) async {
    final res = await _api.get(ApiConfig.stockTransferTransitById(id));
    final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return TransferOrderDispatchDto.fromJson(data);
  }

  Future<TransferOrderDispatchDto> recordPing(
      String id, double lat, double lng, String locationName, {String? notes}) async {
    final res = await _api.post(
      ApiConfig.stockTransferTransitPing(id),
      data: {
        'latitude': lat,
        'longitude': lng,
        'locationName': locationName,
        'eventType': 'CHECKPOINT',
        if (notes != null) 'eventNotes': notes,
      },
    );
    final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return TransferOrderDispatchDto.fromJson(data);
  }

  Future<TransferOrderDispatchDto> markDelivered(String id) async {
    final res = await _api.post(ApiConfig.stockTransferTransitDeliver(id));
    final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return TransferOrderDispatchDto.fromJson(data);
  }

  Future<TransferOrderDispatchDto> receiveAtDestination(String id) async {
    final res = await _api.post(ApiConfig.stockTransferTransitReceive(id));
    final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return TransferOrderDispatchDto.fromJson(data);
  }
}
