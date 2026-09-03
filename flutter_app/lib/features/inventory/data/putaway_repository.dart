import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final putawayRepositoryProvider = Provider<PutawayRepository>((ref) {
  return PutawayRepository(ref.watch(apiClientProvider));
});

class PutawayTaskLineDto {
  final String id;
  final String itemId;
  final String? batchNumber;
  final double quantity;
  final String? suggestedRackId;
  final String? confirmedRackId;
  final String status;
  final String? confirmedAt;
  final String? confirmedBy;

  const PutawayTaskLineDto({
    required this.id,
    required this.itemId,
    this.batchNumber,
    required this.quantity,
    this.suggestedRackId,
    this.confirmedRackId,
    required this.status,
    this.confirmedAt,
    this.confirmedBy,
  });

  factory PutawayTaskLineDto.fromJson(Map<String, dynamic> json) {
    return PutawayTaskLineDto(
      id: json['id'] as String,
      itemId: json['itemId'] as String,
      batchNumber: json['batchNumber'] as String?,
      quantity: (json['quantity'] as num).toDouble(),
      suggestedRackId: json['suggestedRackId'] as String?,
      confirmedRackId: json['confirmedRackId'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      confirmedAt: json['confirmedAt'] as String?,
      confirmedBy: json['confirmedBy'] as String?,
    );
  }
}

class PutawayTaskDto {
  final String id;
  final String orgId;
  final String taskNumber;
  final String? goodsReceiptId;
  final String warehouseId;
  final String sourceLocation;
  final String status;
  final String? assignedTo;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final List<PutawayTaskLineDto> lines;

  const PutawayTaskDto({
    required this.id,
    required this.orgId,
    required this.taskNumber,
    this.goodsReceiptId,
    required this.warehouseId,
    required this.sourceLocation,
    required this.status,
    this.assignedTo,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.lines,
  });

  factory PutawayTaskDto.fromJson(Map<String, dynamic> json) {
    return PutawayTaskDto(
      id: json['id'] as String,
      orgId: json['orgId'] as String,
      taskNumber: json['taskNumber'] as String,
      goodsReceiptId: json['goodsReceiptId'] as String?,
      warehouseId: json['warehouseId'] as String,
      sourceLocation: json['sourceLocation'] as String? ?? 'RECEIVING_DOCK',
      status: json['status'] as String? ?? 'PENDING',
      assignedTo: json['assignedTo'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      lines: (json['lines'] as List<dynamic>?)
              ?.map((e) => PutawayTaskLineDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class PutawayRepository {
  final ApiClient _api;
  PutawayRepository(this._api);

  Future<List<PutawayTaskDto>> listTasks({String? status}) async {
    final res = await _api.get(
      ApiConfig.putawayTasks,
      queryParameters: {
        if (status != null && status != 'ALL') 'status': status,
      },
    );
    final list = (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return list.map((e) => PutawayTaskDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PutawayTaskDto> getTask(String id) async {
    final res = await _api.get(ApiConfig.putawayTaskById(id));
    final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return PutawayTaskDto.fromJson(data);
  }

  Future<PutawayTaskDto> confirmLine(String taskId, String lineId, String confirmedRackId) async {
    final res = await _api.post(
      ApiConfig.putawayTaskConfirmLine(taskId, lineId),
      data: {'confirmedRackId': confirmedRackId},
    );
    final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return PutawayTaskDto.fromJson(data);
  }

  Future<PutawayTaskDto> cancelTask(String taskId) async {
    final res = await _api.post(ApiConfig.putawayTaskCancel(taskId));
    final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return PutawayTaskDto.fromJson(data);
  }
}