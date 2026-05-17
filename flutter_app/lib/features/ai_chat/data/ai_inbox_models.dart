class AiInboxSummary {
  final int pending;
  final int highPriorityPending;

  const AiInboxSummary({
    required this.pending,
    required this.highPriorityPending,
  });

  factory AiInboxSummary.fromMap(Map<String, dynamic> map) {
    return AiInboxSummary(
      pending: (map['pending'] as num?)?.toInt() ?? 0,
      highPriorityPending: (map['highPriorityPending'] as num?)?.toInt() ?? 0,
    );
  }
}

class AiSuggestionItem {
  final String id;
  final String entityType;
  final String? entityId;
  final String suggestionType;
  final String? suggestedAction;
  final Map<String, dynamic> suggestedValue;
  final String reasoning;
  final double confidence;
  final String? agentName;
  final String? modelName;
  final String? modelVersion;
  final String status;
  final String priority;
  final double priorityScore;
  final DateTime? dueBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AiSuggestionItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.suggestionType,
    required this.suggestedAction,
    required this.suggestedValue,
    required this.reasoning,
    required this.confidence,
    required this.agentName,
    required this.modelName,
    required this.modelVersion,
    required this.status,
    required this.priority,
    required this.priorityScore,
    required this.dueBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AiSuggestionItem.fromMap(Map<String, dynamic> map) {
    return AiSuggestionItem(
      id: map['id']?.toString() ?? '',
      entityType: map['entityType']?.toString() ?? 'UNKNOWN',
      entityId: map['entityId']?.toString(),
      suggestionType: map['suggestionType']?.toString() ?? 'UNKNOWN',
      suggestedAction: map['suggestedAction']?.toString(),
      suggestedValue: Map<String, dynamic>.from(
        (map['suggestedValue'] as Map?) ?? const {},
      ),
      reasoning: map['reasoning']?.toString() ?? '',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      agentName: map['agentName']?.toString(),
      modelName: map['modelName']?.toString(),
      modelVersion: map['modelVersion']?.toString(),
      status: map['status']?.toString() ?? 'PENDING',
      priority: map['priority']?.toString() ?? 'MEDIUM',
      priorityScore: (map['priorityScore'] as num?)?.toDouble() ?? 0,
      dueBy: _parseDate(map['dueBy']),
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class AiSuggestionPage {
  final List<AiSuggestionItem> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;

  const AiSuggestionPage({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  factory AiSuggestionPage.fromMap(Map<String, dynamic> map) {
    final rawContent = (map['content'] as List?) ?? const [];
    return AiSuggestionPage(
      content: rawContent
          .whereType<Map>()
          .map((item) => AiSuggestionItem.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
      page: (map['page'] as num?)?.toInt() ?? 0,
      size: (map['size'] as num?)?.toInt() ?? rawContent.length,
      totalElements:
          (map['totalElements'] as num?)?.toInt() ?? rawContent.length,
      totalPages: (map['totalPages'] as num?)?.toInt() ?? 1,
      last: map['last'] as bool? ?? true,
    );
  }
}
