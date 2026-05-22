package com.katasticho.erp.ca.dto;

import java.util.UUID;

public record AssignClientRequest(
        UUID assignedUserId,
        UUID backupUserId
) {
}
