package com.katasticho.erp.ca.dto;

import java.util.UUID;

public record CaFirmResponse(
        UUID id,
        UUID orgId,
        String firmName,
        String icaiNumber,
        boolean active
) {
}
