package com.katasticho.erp.inventory.dto;

import java.util.UUID;

public record ManufacturerMasterResponse(
        UUID id,
        String name,
        String country,
        String website
) {}
