package com.katasticho.erp.ca.dto;

import java.util.UUID;

public record CaStaffResponse(
        UUID userId,
        String fullName,
        String email,
        String phone,
        String role,
        long clientCount,
        boolean active
) {
}
