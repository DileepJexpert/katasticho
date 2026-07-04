package com.katasticho.erp.banking.dto;

import java.math.BigDecimal;
import java.util.UUID;

/** DTOs for user-defined bank matching rules. */
public final class BankRuleDtos {

    private BankRuleDtos() {}

    public record BankRuleRequest(
            String name,
            Integer priority,
            Boolean active,
            String directionFilter,   // ANY | CREDIT | DEBIT
            String narrationOp,       // CONTAINS | EQUALS | STARTS_WITH | REGEX
            String narrationValue,
            String amountOp,          // ANY | EQ | GT | LT | GTE | LTE
            BigDecimal amountValue,
            String accountCode,       // target GL for the categorisation
            UUID contactId,           // optional payee/payer metadata
            String memo,
            Boolean autoApply) {}

    public record BankRuleResponse(
            UUID id, String name, int priority, boolean active,
            String directionFilter, String narrationOp, String narrationValue,
            String amountOp, BigDecimal amountValue,
            String accountCode, String accountName,
            UUID contactId, String memo, boolean autoApply) {}
}
