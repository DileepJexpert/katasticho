package com.katasticho.erp.payroll.dto;

import jakarta.validation.constraints.NotBlank;
import java.time.LocalDate;

public record EmployeeRequest(
    String employeeCode,
    @NotBlank String fullName,
    String phone,
    String email,
    String designation,
    String department,
    LocalDate dateOfJoining,
    String paymentMode,
    String bankAccountName,
    String bankAccountNumber,
    String bankIfsc,
    String pan,
    String aadhaarLast4,
    String uan,
    String esiNumber,
    boolean isPfApplicable,
    boolean isEsiApplicable,
    boolean isPtApplicable,
    boolean isLwfApplicable
) {}
