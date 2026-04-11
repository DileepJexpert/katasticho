package com.katasticho.erp.accounting.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Child of JournalEntry. Immutable once parent is POSTED.
 * Dual amounts: transaction currency + base currency (multi-currency ready).
 */
@Entity
@Table(name = "journal_line")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class JournalLine {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "journal_entry_id", nullable = false)
    private JournalEntry journalEntry;

    @Column(name = "account_id", nullable = false)
    private UUID accountId;

    @Column(length = 500)
    private String description;

    @Column(nullable = false, length = 3)
    @Builder.Default
    private String currency = "INR";

    @Column(nullable = false)
    @Builder.Default
    private BigDecimal debit = BigDecimal.ZERO;

    @Column(nullable = false)
    @Builder.Default
    private BigDecimal credit = BigDecimal.ZERO;

    @Column(name = "exchange_rate", nullable = false)
    @Builder.Default
    private BigDecimal exchangeRate = BigDecimal.ONE;

    @Column(name = "base_debit", nullable = false)
    @Builder.Default
    private BigDecimal baseDebit = BigDecimal.ZERO;

    @Column(name = "base_credit", nullable = false)
    @Builder.Default
    private BigDecimal baseCredit = BigDecimal.ZERO;

    @Column(name = "tax_component_code", length = 20)
    private String taxComponentCode;

    @Column(name = "cost_centre", length = 50)
    private String costCentre;

    @Column(name = "project_id")
    private UUID projectId;
}
