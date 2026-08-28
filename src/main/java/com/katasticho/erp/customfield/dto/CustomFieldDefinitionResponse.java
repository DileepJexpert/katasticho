package com.katasticho.erp.customfield.dto;

import com.katasticho.erp.customfield.entity.FieldType;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record CustomFieldDefinitionResponse(
        UUID id,
        String entityType,
        String fieldName,
        String fieldLabel,
        FieldType fieldType,
        boolean isRequired,
        String defaultValue,
        List<String> options,
        String validationRegex,
        int sortOrder,
        boolean isActive,
        boolean showInGrid,
        boolean showInPdf,
        Instant createdAt,
        Instant updatedAt
) {}
