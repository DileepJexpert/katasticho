package com.katasticho.erp.payroll.dto;

import jakarta.validation.constraints.NotBlank;

public record SalaryComponentRequest(
    @NotBlank String code,
    @NotBlank String name,
    @NotBlank String componentType,
    String taxability,
    boolean isStatutory
) {}
