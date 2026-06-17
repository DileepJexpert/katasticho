package com.katasticho.erp.payroll.dto;

import jakarta.validation.constraints.NotBlank;
import java.time.LocalDate;
import java.util.UUID;

public record EmployeeRequest(
    // ── Identity ──
    String employeeCode,
    @NotBlank String fullName,
    String phone,
    String email,
    String designation,
    String department,
    LocalDate dateOfJoining,

    // ── Payment / statutory ──
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
    boolean isLwfApplicable,

    /** Optional app-user link — enables attendance/leave (LOP) integration. */
    UUID userId,

    // ── Personal info (V18) ──
    LocalDate dateOfBirth,
    String gender,
    String maritalStatus,
    String bloodGroup,
    String nationality,
    String personalEmail,

    // ── Current address ──
    String currentAddressLine1,
    String currentAddressLine2,
    String currentCity,
    String currentState,
    String currentPincode,

    // ── Permanent address ──
    String permanentAddressLine1,
    String permanentAddressLine2,
    String permanentCity,
    String permanentState,
    String permanentPincode,

    // ── Emergency contact ──
    String emergencyContactName,
    String emergencyContactRelationship,
    String emergencyContactPhone,

    // ── Work info ──
    String employmentType,
    String workLocation,
    LocalDate probationEndDate,
    LocalDate confirmationDate,
    Integer noticePeriodDays,
    UUID photoAttachmentId
) {}
