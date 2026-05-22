package com.katasticho.erp.gst.dto;

import com.katasticho.erp.ai.entity.AiSuggestion;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

public record GstReviewIssueResponse(
        UUID id,
        String status,
        String priority,
        BigDecimal priorityScore,
        String severity,
        String category,
        String title,
        String reasoning,
        BigDecimal confidence,
        String entityType,
        UUID entityId,
        UUID entityLineId,
        String sourceNumber,
        Map<String, Object> suggestedValue,
        Instant createdAt
) {
    public static GstReviewIssueResponse from(AiSuggestion suggestion) {
        Map<String, Object> value = suggestion.getSuggestedValue();
        String title = value == null ? null : stringValue(value.get("title"));
        String sourceNumber = value == null ? null : stringValue(value.get("sourceNumber"));
        if (title == null || title.isBlank()) {
            title = defaultTitle(suggestion.getSuggestionType());
        }
        return new GstReviewIssueResponse(
                suggestion.getId(),
                suggestion.getStatus(),
                suggestion.getPriority(),
                suggestion.getPriorityScore(),
                toSeverity(suggestion.getPriority()),
                suggestion.getSuggestionType(),
                title,
                suggestion.getReasoning(),
                suggestion.getConfidence(),
                suggestion.getEntityType(),
                suggestion.getEntityId(),
                suggestion.getEntityLineId(),
                sourceNumber,
                value,
                suggestion.getCreatedAt()
        );
    }

    private static String stringValue(Object value) {
        return value == null ? null : value.toString();
    }

    private static String toSeverity(String priority) {
        return switch (priority == null ? "" : priority) {
            case "CRITICAL" -> "Critical";
            case "HIGH" -> "High";
            case "LOW" -> "Low";
            default -> "Medium";
        };
    }

    private static String defaultTitle(String type) {
        return switch (type == null ? "" : type) {
            case "GST_AMOUNT_MISMATCH" -> "GST amount mismatch";
            case "MISSING_HSN" -> "Missing HSN/SAC";
            case "INVALID_GSTIN" -> "Invalid GSTIN";
            case "INVALID_GST_RATE" -> "Invalid GST rate";
            case "B2B_INVOICE_WITHOUT_GSTIN" -> "B2B invoice missing GSTIN";
            case "DUPLICATE_INVOICE" -> "Possible duplicate invoice";
            case "MISSING_TAX_ACCOUNT_MAPPING" -> "Missing tax account mapping";
            default -> type == null ? "GST review issue" : type.replace('_', ' ');
        };
    }
}
