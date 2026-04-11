package com.katasticho.erp.ai.dto;

import jakarta.validation.constraints.NotBlank;

public record BillScanRequest(
        @NotBlank(message = "Image data is required")
        String image,

        String mediaType // e.g., "image/jpeg", "image/png"
) {
    public String effectiveMediaType() {
        return mediaType != null ? mediaType : "image/jpeg";
    }
}
