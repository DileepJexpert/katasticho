package com.katasticho.erp.recurring.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/**
 * Audit link between a {@link RecurringInvoice} template and each
 * invoice the scheduler produced from it. Enables the "generated
 * invoices" panel on the detail screen without touching the heavy
 * invoice table.
 */
@Entity
@Table(name = "recurring_invoice_generation")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RecurringInvoiceGeneration {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "recurring_invoice_id", nullable = false, updatable = false)
    private UUID recurringInvoiceId;

    @Column(name = "invoice_id", nullable = false, updatable = false)
    private UUID invoiceId;

    @Column(name = "generated_at", nullable = false, updatable = false)
    private Instant generatedAt;

    @Column(name = "auto_sent", nullable = false)
    @Builder.Default
    private boolean autoSent = false;

    @PrePersist
    protected void onCreate() {
        if (this.generatedAt == null) this.generatedAt = Instant.now();
    }
}
