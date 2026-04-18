package com.katasticho.erp.common.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;

import java.util.List;
import java.util.UUID;

public record BulkIdsRequest(
        @NotEmpty(message = "ids must not be empty")
        @Size(max = 100, message = "Maximum 100 ids per bulk request")
        List<UUID> ids,

        String reason
) {
    public String resolvedReason(String defaultReason) {
        return (reason != null && !reason.isBlank()) ? reason : defaultReason;
    }
}
