package com.katasticho.erp.ar.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "credit_note")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CreditNote {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false, updatable = false)
    private UUID orgId;

    @Column(name = "contact_id", nullable = false)
    private UUID contactId;

    @Column(name = "invoice_id")
    private UUID invoiceId;

    @Column(name = "credit_note_number", nullable = false, length = 30)
    private String creditNoteNumber;

    @Column(name = "credit_note_date", nullable = false)
    private LocalDate creditNoteDate;

    @Column(nullable = false)
    private String reason;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "DRAFT";

    // Amounts
    @Builder.Default
    private BigDecimal subtotal = BigDecimal.ZERO;
    @Column(name = "tax_amount")
    @Builder.Default
    private BigDecimal taxAmount = BigDecimal.ZERO;
    @Column(name = "total_amount")
    @Builder.Default
    private BigDecimal totalAmount = BigDecimal.ZERO;

    @Column(nullable = false, length = 3)
    @Builder.Default
    private String currency = "INR";

    @Column(name = "exchange_rate", nullable = false)
    @Builder.Default
    private BigDecimal exchangeRate = BigDecimal.ONE;

    // Base currency
    @Column(name = "base_subtotal")
    @Builder.Default
    private BigDecimal baseSubtotal = BigDecimal.ZERO;
    @Column(name = "base_tax_amount")
    @Builder.Default
    private BigDecimal baseTaxAmount = BigDecimal.ZERO;
    @Column(name = "base_total")
    @Builder.Default
    private BigDecimal baseTotal = BigDecimal.ZERO;

    @Column(name = "place_of_supply", length = 5)
    private String placeOfSupply;

    @Column(name = "journal_entry_id")
    private UUID journalEntryId;

    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private boolean isDeleted = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "created_by", updatable = false)
    private UUID createdBy;

    @OneToMany(mappedBy = "creditNote", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<CreditNoteLine> lines = new ArrayList<>();

    public void addLine(CreditNoteLine line) {
        lines.add(line);
        line.setCreditNote(this);
    }

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
        this.updatedAt = Instant.now();
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
