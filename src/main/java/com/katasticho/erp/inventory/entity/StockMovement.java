package com.katasticho.erp.inventory.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/**
 * IMMUTABLE append-only stock ledger entry.
 *
 * Mirrors {@link com.katasticho.erp.accounting.entity.JournalEntry}: the only
 * mutation allowed once persisted is flipping {@code isReversed} from FALSE
 * to TRUE (and that is enforced by a database trigger as well as application
 * code). Corrections happen by recording a new movement of the opposite
 * sign with {@code isReversal=true} and {@code reversalOfId} pointing back.
 *
 * Does NOT extend BaseEntity because it has no updated_at and no isDeleted —
 * the row is permanent and the trigger blocks DELETE entirely.
 */
@Entity
@Table(name = "stock_movement")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StockMovement {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false, updatable = false)
    private UUID orgId;

    @Column(name = "item_id", nullable = false, updatable = false)
    private UUID itemId;

    @Column(name = "warehouse_id", nullable = false, updatable = false)
    private UUID warehouseId;

    /** Business time — when the movement actually happened. */
    @Column(name = "movement_date", nullable = false, updatable = false)
    private LocalDate movementDate;

    /** System time — when the row was inserted. */
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Enumerated(EnumType.STRING)
    @Column(name = "movement_type", nullable = false, length = 20, updatable = false)
    private MovementType movementType;

    /**
     * SIGNED quantity. Positive = stock in, negative = stock out.
     * The signed convention lets {@code SUM(quantity)} compute on-hand directly,
     * just like {@code SUM(debit) - SUM(credit)} on a ledger account.
     */
    @Column(nullable = false, updatable = false)
    private BigDecimal quantity;

    @Column(name = "unit_cost", nullable = false, updatable = false)
    @Builder.Default
    private BigDecimal unitCost = BigDecimal.ZERO;

    @Column(name = "total_cost", nullable = false, updatable = false)
    @Builder.Default
    private BigDecimal totalCost = BigDecimal.ZERO;

    @Enumerated(EnumType.STRING)
    @Column(name = "reference_type", length = 30, updatable = false)
    private ReferenceType referenceType;

    @Column(name = "reference_id", updatable = false)
    private UUID referenceId;

    @Column(name = "reference_number", length = 50, updatable = false)
    private String referenceNumber;

    @Column(name = "is_reversal", nullable = false, updatable = false)
    @Builder.Default
    private boolean reversal = false;

    @Column(name = "reversal_of_id", updatable = false)
    private UUID reversalOfId;

    /** The ONLY field allowed to mutate after insert. */
    @Column(name = "is_reversed", nullable = false)
    @Builder.Default
    private boolean reversed = false;

    @Column(columnDefinition = "TEXT", updatable = false)
    private String notes;

    @Column(name = "created_by", updatable = false)
    private UUID createdBy;

    @PrePersist
    protected void onCreate() {
        if (this.createdAt == null) {
            this.createdAt = Instant.now();
        }
    }
}
