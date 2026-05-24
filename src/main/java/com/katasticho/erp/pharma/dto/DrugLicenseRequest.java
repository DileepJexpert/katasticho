package com.katasticho.erp.pharma.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;

public record DrugLicenseRequest(
    @NotBlank String licenseType,
    @NotBlank String licenseNumber,
    String issuedBy,
    LocalDate issueDate,
    @NotNull LocalDate expiryDate,
    String notes
) {}
