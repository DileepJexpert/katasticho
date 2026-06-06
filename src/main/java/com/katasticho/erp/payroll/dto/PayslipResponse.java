package com.katasticho.erp.payroll.dto;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record PayslipResponse(
    UUID id,
    UUID employeeId,
    String employeeName,
    String employeeCode,
    BigDecimal grossPay,
    BigDecimal totalDeductions,
    BigDecimal employerContributions,
    BigDecimal netPay,
    String status,
    List<PayslipLineResponse> lines
) {
    public record PayslipLineResponse(
        UUID componentId,
        String componentCode,
        String componentName,
        String componentType,
        BigDecimal amount
    ) {}
}
