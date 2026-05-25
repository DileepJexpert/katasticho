package com.katasticho.erp.inventory.dto;

import java.util.UUID;

public record DrugInteractionResponse(
        UUID id,
        UUID primarySaltId,
        UUID interactingSaltId,
        String severity,
        String warning,
        String recommendation
) {}
