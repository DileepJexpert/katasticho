package com.katasticho.erp.expense.reimbursement.dto;

import jakarta.validation.constraints.NotNull;
import java.util.UUID;

public record PayReimbursementRequest(@NotNull UUID paidThroughId) {}
