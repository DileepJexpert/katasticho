package com.katasticho.erp.customfield.dto;

import com.katasticho.erp.customfield.entity.FieldType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

import java.util.List;

public record CustomFieldDefinitionRequest(
        @NotBlank(message = "Entity type is required")
        String entityType,

        @NotBlank(message = "Field name is required")
        @Pattern(regexp = "^[a-z0-9_]{2,50}$", message = "Field name must be lowercase alphanumeric with underscores (2-50 chars)")
        String fieldName,

        @NotBlank(message = "Field label is required")
        String fieldLabel,

        @NotNull(message = "Field type is required")
        FieldType fieldType,

        Boolean isRequired,
        String defaultValue,
        List<String> options,
        String validationRegex,
        Integer sortOrder,
        Boolean isActive,
        Boolean showInGrid,
        Boolean showInPdf
) {}
