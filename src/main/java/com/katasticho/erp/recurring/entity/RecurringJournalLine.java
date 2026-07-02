package com.katasticho.erp.recurring.entity;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * A single template line inside the JSONB payload on
 * {@link RecurringJournal#lines}. Maps directly to a JournalLineRequest at
 * generation time.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class RecurringJournalLine {

    /** GL account code (resolved per org at generation). */
    private String accountCode;

    private BigDecimal debit;

    private BigDecimal credit;

    private String description;

    private String costCentre;

    private String taxComponentCode;
}
