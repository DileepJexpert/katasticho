package com.katasticho.erp.ca.dto;

import java.util.UUID;

public record InviteClientRequest(
        UUID clientOrgId,
        String clientName,
        String emailOrPhone,
        String engagementType,
        UUID assignedUserId,
        String notes
) {
}
