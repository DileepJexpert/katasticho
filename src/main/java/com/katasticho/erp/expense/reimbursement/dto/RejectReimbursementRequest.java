package com.katasticho.erp.expense.reimbursement.dto;

import jakarta.validation.constraints.NotBlank;

public record RejectReimbursementRequest(@NotBlank String reason) {}
