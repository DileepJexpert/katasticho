package com.katasticho.erp.banking.reconciliation.dto;

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
public class AutoMatchRunRequest {

    @NotNull(message = "Bank account ID is required")
    private UUID bankAccountId;

    private List<StatementLineInput> statementLines;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class StatementLineInput {
        @NotNull(message = "Date is required")
        private LocalDate date;
        private String reference;
        private String description;
        @NotNull(message = "Amount is required")
        private BigDecimal amount;
        private boolean credit;
    }
}