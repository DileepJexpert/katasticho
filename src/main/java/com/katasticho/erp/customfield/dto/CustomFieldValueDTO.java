package com.katasticho.erp.customfield.dto;

import com.katasticho.erp.customfield.entity.FieldType;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CustomFieldValueDTO(
        UUID fieldDefinitionId,
        String fieldName,
        String fieldLabel,
        FieldType fieldType,
        boolean isRequired,
        List<String> options,
        boolean showInGrid,
        boolean showInPdf,
        int sortOrder,
        String valueText,
        BigDecimal valueNumber,
        LocalDate valueDate,
        Boolean valueBoolean
) {}
