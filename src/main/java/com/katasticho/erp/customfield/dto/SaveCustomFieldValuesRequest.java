package com.katasticho.erp.customfield.dto;

import jakarta.validation.constraints.NotEmpty;

import java.util.List;

public record SaveCustomFieldValuesRequest(
        @NotEmpty(message = "Values list cannot be empty")
        List<CustomFieldValueInput> values
) {}
