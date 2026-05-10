package com.katasticho.erp.ai.dto;

import com.katasticho.erp.ai.entity.AiSuggestion;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

public record AiSuggestionResponse(
        UUID id,
        UUID orgId,
        String entityType,
        UUID entityId,
        UUID entityLineId,
        String suggestionType,
        String suggestedAction,
        Map<String, Object> suggestedValue,
        String reasoning,
        BigDecimal confidence,
        String agentName,
        String modelName,
        String modelVersion,
        String promptVersion,
        String status,
        UUID reviewedBy,
        Instant reviewedAt,
        String reviewAction,
        Map<String, Object> reviewedValue,
        String correctionReason,
        String priority,
        BigDecimal priorityScore,
        Instant dueBy,
        Instant createdAt,
        Instant updatedAt
) {
    public static AiSuggestionResponse from(AiSuggestion suggestion) {
        return new AiSuggestionResponse(
                suggestion.getId(),
                suggestion.getOrgId(),
                suggestion.getEntityType(),
                suggestion.getEntityId(),
                suggestion.getEntityLineId(),
                suggestion.getSuggestionType(),
                suggestion.getSuggestedAction(),
                suggestion.getSuggestedValue(),
                suggestion.getReasoning(),
                suggestion.getConfidence(),
                suggestion.getAgentName(),
                suggestion.getModelName(),
                suggestion.getModelVersion(),
                suggestion.getPromptVersion(),
                suggestion.getStatus(),
                suggestion.getReviewedBy(),
                suggestion.getReviewedAt(),
                suggestion.getReviewAction(),
                suggestion.getReviewedValue(),
                suggestion.getCorrectionReason(),
                suggestion.getPriority(),
                suggestion.getPriorityScore(),
                suggestion.getDueBy(),
                suggestion.getCreatedAt(),
                suggestion.getUpdatedAt()
        );
    }
}
