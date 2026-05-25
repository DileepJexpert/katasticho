package com.katasticho.erp.inventory.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record RackLocationRequest(
        @NotNull UUID warehouseId,
        @NotBlank String code,
        String name,
        String zone,
        String aisle,
        String shelf,
        String bin
) {}
