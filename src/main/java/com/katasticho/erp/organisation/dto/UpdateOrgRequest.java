package com.katasticho.erp.organisation.dto;

import jakarta.validation.constraints.Size;

public record UpdateOrgRequest(
        @Size(max = 255) String name,
        @Size(max = 20) String phone,
        @Size(max = 255) String email,
        @Size(max = 15) String gstin,
        String addressLine1,
        String addressLine2,
        @Size(max = 100) String city,
        @Size(max = 100) String state,
        @Size(max = 5) String stateCode,
        @Size(max = 20) String postalCode
) {}
