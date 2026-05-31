package com.katasticho.erp.common.workflow;

import java.util.List;
import java.util.UUID;

public record DocumentStateConfigResponse(
        UUID id,
        String documentType,
        String fromState,
        String toState,
        List<String> allowedRoles,
        boolean requiresApproval,
        boolean active
) {
    public static DocumentStateConfigResponse from(DocumentStateConfig config) {
        return new DocumentStateConfigResponse(
                config.getId(),
                config.getDocumentType(),
                config.getFromState(),
                config.getToState(),
                List.of(config.getAllowedRoles()),
                config.isRequiresApproval(),
                config.isActive());
    }
}
