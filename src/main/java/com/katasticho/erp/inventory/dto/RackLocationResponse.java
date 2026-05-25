package com.katasticho.erp.inventory.dto;

import java.util.UUID;

public record RackLocationResponse(
        UUID id,
        UUID warehouseId,
        String code,
        String name,
        String zone,
        String aisle,
        String shelf,
        String bin,
        boolean active
) {}
