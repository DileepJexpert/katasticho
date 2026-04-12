package com.katasticho.erp.procurement.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SupplierRequest(
        @NotBlank @Size(max = 255) String name,
        @Size(max = 15) String gstin,
        @Size(max = 10) String pan,
        @Size(max = 30) String phone,
        String email,
        String addressLine1,
        String addressLine2,
        String city,
        String state,
        String stateCode,
        String postalCode,
        String country,
        Integer paymentTermsDays,
        String notes,
        Boolean active
) {}
