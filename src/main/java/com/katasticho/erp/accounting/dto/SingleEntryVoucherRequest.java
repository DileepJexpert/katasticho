package com.katasticho.erp.accounting.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SingleEntryVoucherRequest {

    public enum VoucherType {
        PAYMENT,  // Header Cash/Bank is CREDITED, line accounts are DEBITED
        RECEIPT,  // Header Cash/Bank is DEBITED, line accounts are CREDITED
        CONTRA    // Money transfer between Cash & Bank accounts
    }

    @NotNull(message = "Voucher type is required")
    private VoucherType voucherType;

    @NotNull(message = "Primary Cash/Bank account is required")
    private UUID primaryAccountId;

    @NotNull(message = "Date is required")
    private LocalDate date;

    private String referenceNumber;
    private String narration;
    private String status; // DRAFT or POSTED (defaults to POSTED)

    @NotEmpty(message = "At least one entry line is required")
    private List<SingleEntryLine> lines;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SingleEntryLine {
        @NotNull(message = "Line account is required")
        private UUID accountId;

        @NotNull(message = "Line amount is required")
        private BigDecimal amount;

        private String narration;
        private UUID costCenterId;
    }
}
