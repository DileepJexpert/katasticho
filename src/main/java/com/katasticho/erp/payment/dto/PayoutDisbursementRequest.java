package com.katasticho.erp.payment.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record PayoutDisbursementRequest(
    @NotNull UUID contactId,
    @NotNull @DecimalMin("0.01") BigDecimal amount,
    @NotNull UUID paidThroughAccountId, // Cash/Bank Ledger
    String payoutMode, // IMPS, NEFT, RTGS, UPI
    String beneficiaryName,
    String accountNumber,
    String ifscCode,
    String vpa,
    String narration,
    List<BillAllocation> billAllocations
) {
    public record BillAllocation(
        @NotNull UUID billId,
        @NotNull @DecimalMin("0.01") BigDecimal amountApplied
    ) {}
}
