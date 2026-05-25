package com.katasticho.erp.inventory.dto;

import java.util.UUID;

public record SaltMasterResponse(
        UUID id,
        String name,
        String category
) {}
