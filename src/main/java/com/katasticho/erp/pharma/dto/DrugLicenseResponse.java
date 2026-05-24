package com.katasticho.erp.pharma.dto;

import java.time.LocalDate;
import java.util.UUID;

public record DrugLicenseResponse(
    UUID id,
    String licenseType,
    String licenseNumber,
    String issuedBy,
    LocalDate issueDate,
    LocalDate expiryDate,
    String notes,
    int daysUntilExpiry,
    String status  // OK / WARNING / CRITICAL / EXPIRED
) {}
