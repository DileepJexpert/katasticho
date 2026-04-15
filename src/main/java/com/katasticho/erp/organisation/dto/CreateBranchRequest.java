package com.katasticho.erp.organisation.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateBranchRequest(
        @NotBlank @Size(max = 20) String code,
        @NotBlank @Size(max = 255) String name,
        String addressLine1,
        String addressLine2,
        @Size(max = 100) String city,
        @Size(max = 100) String state,
        @Size(max = 5) String stateCode,
        @Size(max = 20) String postalCode,
        @Size(max = 2) String country,
        @Size(max = 15) String gstin,
        Boolean isDefault
) {}
