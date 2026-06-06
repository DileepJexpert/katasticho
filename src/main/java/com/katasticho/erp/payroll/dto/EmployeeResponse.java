package com.katasticho.erp.payroll.dto;

import java.time.LocalDate;
import java.util.UUID;

public record EmployeeResponse(
    UUID id,
    String employeeCode,
    String fullName,
    String phone,
    String email,
    String designation,
    String department,
    LocalDate dateOfJoining,
    LocalDate dateOfExit,
    String employmentStatus,
    String paymentMode,
    String pan,
    String uan,
    String esiNumber,
    boolean isPfApplicable,
    boolean isEsiApplicable,
    boolean isPtApplicable,
    boolean isLwfApplicable
) {}
