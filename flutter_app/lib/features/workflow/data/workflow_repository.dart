import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

final workflowRepositoryProvider = Provider<WorkflowRepository>((ref) {
  return WorkflowRepository(ref.watch(apiClientProvider));
});

final workflowsProvider = FutureProvider<List<WorkflowDefinition>>((ref) {
  return ref.read(workflowRepositoryProvider).listWorkflows();
});

final approvalRequestsProvider = FutureProvider<List<ApprovalRequest>>((ref) {
  return ref.read(workflowRepositoryProvider).listApprovalRequests(
        status: 'PENDING',
      );
});

final approvalRequestForDocumentProvider =
    FutureProvider.family<ApprovalRequest?, String>((ref, key) {
  final parts = key.split('|');
  if (parts.length != 2) return Future.value(null);
  return ref.read(workflowRepositoryProvider).getApprovalForDocument(
        documentType: parts[0],
        documentId: parts[1],
      );
});

final approvalHistoryForDocumentProvider =
    FutureProvider.family<ApprovalHistory, String>((ref, key) {
  final parts = key.split('|');
  if (parts.length != 2) {
    return Future.value(const ApprovalHistory(requests: [], decisions: []));
  }
  return ref.read(workflowRepositoryProvider).getApprovalHistoryForDocument(
        documentType: parts[0],
        documentId: parts[1],
      );
});

class WorkflowDefinition {
  final String id;
  final String code;
  final String name;
  final String documentType;
  final bool active;
  final String triggerCondition;
  final List<WorkflowStep> steps;

  const WorkflowDefinition({
    required this.id,
    required this.code,
    required this.name,
    required this.documentType,
    required this.active,
    required this.triggerCondition,
    required this.steps,
  });

  factory WorkflowDefinition.fromJson(Map<String, dynamic> json) {
    return WorkflowDefinition(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Workflow',
      documentType: json['documentType']?.toString() ?? '',
      active: json['active'] as bool? ?? false,
      triggerCondition: json['triggerCondition']?.toString() ?? '{}',
      steps: (json['steps'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(WorkflowStep.fromJson)
          .toList(),
    );
  }
}

class WorkflowStep {
  final String? id;
  final int stepNumber;
  final String? approverRole;
  final String? approverUserId;
  final int timeoutHours;
  final String onTimeout;

  const WorkflowStep({
    this.id,
    required this.stepNumber,
    this.approverRole,
    this.approverUserId,
    required this.timeoutHours,
    required this.onTimeout,
  });

  factory WorkflowStep.fromJson(Map<String, dynamic> json) {
    return WorkflowStep(
      id: json['id']?.toString(),
      stepNumber: (json['stepNumber'] as num?)?.toInt() ?? 1,
      approverRole: json['approverRole']?.toString(),
      approverUserId: json['approverUserId']?.toString(),
      timeoutHours: (json['timeoutHours'] as num?)?.toInt() ?? 24,
      onTimeout: json['onTimeout']?.toString() ?? 'ESCALATE',
    );
  }

  Map<String, dynamic> toRequest() => {
        'stepNumber': stepNumber,
        if (approverRole != null && approverRole!.trim().isNotEmpty)
          'approverRole': approverRole!.trim(),
        if (approverUserId != null && approverUserId!.trim().isNotEmpty)
          'approverUserId': approverUserId!.trim(),
        'timeoutHours': timeoutHours,
        'onTimeout': onTimeout,
      };
}

class ApprovalRequest {
  final String id;
  final String? workflowId;
  final String workflowName;
  final String documentType;
  final String documentId;
  final int currentStep;
  final String triggerReason;
  final String status;
  final String? requestedAt;

  const ApprovalRequest({
    required this.id,
    this.workflowId,
    required this.workflowName,
    required this.documentType,
    required this.documentId,
    required this.currentStep,
    required this.triggerReason,
    required this.status,
    this.requestedAt,
  });

  factory ApprovalRequest.fromJson(Map<String, dynamic> json) {
    return ApprovalRequest(
      id: json['id']?.toString() ?? '',
      workflowId: json['workflowId']?.toString(),
      workflowName: json['workflowName']?.toString() ?? 'Approval',
      documentType: json['documentType']?.toString() ?? '',
      documentId: json['documentId']?.toString() ?? '',
      currentStep: (json['currentStep'] as num?)?.toInt() ?? 1,
      triggerReason: json['triggerReason']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      requestedAt: json['requestedAt']?.toString(),
    );
  }
}

class ApprovalDecision {
  final String id;
  final String approvalRequestId;
  final int stepNumber;
  final String decision;
  final String? note;
  final String? decidedBy;
  final String? decidedAt;

  const ApprovalDecision({
    required this.id,
    required this.approvalRequestId,
    required this.stepNumber,
    required this.decision,
    this.note,
    this.decidedBy,
    this.decidedAt,
  });

  factory ApprovalDecision.fromJson(Map<String, dynamic> json) {
    return ApprovalDecision(
      id: json['id']?.toString() ?? '',
      approvalRequestId: json['approvalRequestId']?.toString() ?? '',
      stepNumber: (json['stepNumber'] as num?)?.toInt() ?? 1,
      decision: json['decision']?.toString() ?? '',
      note: json['note']?.toString(),
      decidedBy: json['decidedBy']?.toString(),
      decidedAt: json['decidedAt']?.toString(),
    );
  }
}

class ApprovalHistory {
  final List<ApprovalRequest> requests;
  final List<ApprovalDecision> decisions;

  const ApprovalHistory({
    required this.requests,
    required this.decisions,
  });

  factory ApprovalHistory.fromJson(Map<String, dynamic> json) {
    return ApprovalHistory(
      requests: (json['requests'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ApprovalRequest.fromJson)
          .toList(),
      decisions: (json['decisions'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ApprovalDecision.fromJson)
          .toList(),
    );
  }

  bool get isEmpty => requests.isEmpty && decisions.isEmpty;
}

class WorkflowRepository {
  final ApiClient _api;

  WorkflowRepository(this._api);

  Future<List<WorkflowDefinition>> listWorkflows() async {
    final response = await _api.get('/api/v1/workflows');
    final data = _unwrapData(response.data);
    final list = data is List ? data : const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(WorkflowDefinition.fromJson)
        .toList();
  }

  Future<WorkflowDefinition> updateWorkflow(
    String id, {
    bool? active,
    String? triggerCondition,
  }) async {
    final response = await _api.put('/api/v1/workflows/$id', data: {
      if (active != null) 'active': active,
      if (triggerCondition != null) 'triggerCondition': triggerCondition,
    });
    final data = _unwrapData(response.data);
    return WorkflowDefinition.fromJson(data as Map<String, dynamic>);
  }

  Future<WorkflowDefinition> replaceSteps(
    String id,
    List<WorkflowStep> steps,
  ) async {
    final response = await _api.put(
      '/api/v1/workflows/$id/steps',
      data: steps.map((s) => s.toRequest()).toList(),
    );
    final data = _unwrapData(response.data);
    return WorkflowDefinition.fromJson(data as Map<String, dynamic>);
  }

  Future<List<ApprovalRequest>> listApprovalRequests({
    String? status,
    int page = 0,
    int size = 50,
  }) async {
    final response = await _api.get(
      '/api/v1/workflow/approval-requests',
      queryParameters: {
        'page': page,
        'size': size,
        if (status != null) 'status': status,
      },
    );
    final data = _unwrapData(response.data);
    final content = data is Map<String, dynamic>
        ? data['content'] as List<dynamic>? ?? const []
        : const [];
    return content
        .whereType<Map<String, dynamic>>()
        .map(ApprovalRequest.fromJson)
        .toList();
  }

  Future<ApprovalRequest?> getApprovalForDocument({
    required String documentType,
    required String documentId,
    String status = 'PENDING',
  }) async {
    final response = await _api.get(
      '/api/v1/workflow/approval-requests/document/$documentType/$documentId',
      queryParameters: {'status': status},
    );
    final data = _unwrapData(response.data);
    if (data is! Map<String, dynamic>) return null;
    return ApprovalRequest.fromJson(data);
  }

  Future<ApprovalHistory> getApprovalHistoryForDocument({
    required String documentType,
    required String documentId,
  }) async {
    final response = await _api.get(
      '/api/v1/workflow/approval-requests/document/$documentType/$documentId/history',
    );
    final data = _unwrapData(response.data);
    if (data is! Map<String, dynamic>) {
      return const ApprovalHistory(requests: [], decisions: []);
    }
    return ApprovalHistory.fromJson(data);
  }

  Future<ApprovalRequest> approve(String id, {String? note}) async {
    final response = await _api.post(
      '/api/v1/workflow/approval-requests/$id/approve',
      data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
    );
    final data = _unwrapData(response.data);
    return ApprovalRequest.fromJson(data as Map<String, dynamic>);
  }

  Future<ApprovalRequest> reject(String id, {String? note}) async {
    final response = await _api.post(
      '/api/v1/workflow/approval-requests/$id/reject',
      data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
    );
    final data = _unwrapData(response.data);
    return ApprovalRequest.fromJson(data as Map<String, dynamic>);
  }

  dynamic _unwrapData(dynamic raw) {
    if (raw is Map<String, dynamic> && raw.containsKey('data')) {
      return raw['data'];
    }
    return raw;
  }
}
