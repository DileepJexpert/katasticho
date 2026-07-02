package com.katasticho.erp.recurring.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/** Audit link: one row per bill minted from a {@link RecurringBill} template. */
@Entity
@Table(name = "recurring_bill_generation")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RecurringBillGeneration {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "recurring_bill_id", nullable = false, updatable = false)
    private UUID recurringBillId;

    @Column(name = "bill_id", nullable = false, updatable = false)
    private UUID billId;

    @Column(name = "generated_at", nullable = false, updatable = false)
    private Instant generatedAt;

    @Column(name = "auto_posted", nullable = false)
    private boolean autoPosted;

    @PrePersist
    void onCreate() {
        if (generatedAt == null) generatedAt = Instant.now();
    }
}
