package com.katasticho.erp.inventory.dto;

import com.katasticho.erp.inventory.entity.UomCategory;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record CreateUomRequest(
        @NotBlank @Size(max = 50) String name,
        @NotBlank @Size(max = 20) String abbreviation,
        @NotNull UomCategory category,
        Boolean base,
        Boolean active
) {}
