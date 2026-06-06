package com.katasticho.erp.payroll.dto;

import java.time.LocalDate;
import java.util.UUID;

public record PayrollSettingsRequest(
    LocalDate payrollStartMonth,
    String payFrequency,
    UUID defaultSalaryExpenseAccountId,
    UUID defaultSalaryPayableAccountId,
    UUID defaultPfPayableAccountId,
    UUID defaultEsiPayableAccountId,
    UUID defaultPtPayableAccountId,
    UUID defaultLwfPayableAccountId,
    UUID defaultTdsPayableAccountId,
    boolean pfEnabled,
    boolean esiEnabled,
    boolean ptEnabled,
    boolean lwfEnabled,
    boolean tdsEnabled
) {}
