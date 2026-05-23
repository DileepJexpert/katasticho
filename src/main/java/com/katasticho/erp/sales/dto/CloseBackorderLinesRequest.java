package com.katasticho.erp.sales.dto;

import jakarta.validation.constraints.NotEmpty;

import java.util.List;
import java.util.UUID;

public record CloseBackorderLinesRequest(
        @NotEmpty(message = "At least one line ID is required")
        List<UUID> lineIds,
        String reason
) {}
