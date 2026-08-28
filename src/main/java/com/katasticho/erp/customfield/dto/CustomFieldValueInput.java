package com.katasticho.erp.customfield.dto;

import java.util.UUID;

public record CustomFieldValueInput(
        UUID fieldDefinitionId,
        String fieldName,
        String value
) {}
