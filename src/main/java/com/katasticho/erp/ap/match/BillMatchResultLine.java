package com.katasticho.erp.ap.match;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Per-line outcome of running 3-way match on a purchase bill. Replace-style
 * — each match run deletes the bill's prior rows and writes fresh ones.
 *
 * <p>{@code status} is one of MATCHED / QTY_OVER / PRICE_HIKE /
 * AMOUNT_MISMATCH / NO_PO / NO_GRN / BYPASSED. Variance columns are signed
 * (positive = bill > expected).
 */
@Entity
@Table(name = "bill_match_result_line")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BillMatchResultLine {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "bill_id", nullable = false)
    private UUID billId;

    @Column(name = "bill_line_id", nullable = false)
    private UUID billLineId;

    @Column(name = "po_line_id")
    private UUID poLineId;

    @Column(name = "grn_line_id")
    private UUID grnLineId;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "billed_qty", nullable = false)
    private BigDecimal billedQty;

    @Column(name = "received_qty")
    private BigDecimal receivedQty;

    @Column(name = "ordered_qty")
    private BigDecimal orderedQty;

    @Column(name = "bill_unit_price", nullable = false)
    private BigDecimal billUnitPrice;

    @Column(name = "po_unit_price")
    private BigDecimal poUnitPrice;

    @Column(name = "qty_variance")
    private BigDecimal qtyVariance;

    @Column(name = "price_variance")
    private BigDecimal priceVariance;

    @Column(name = "amount_variance")
    private BigDecimal amountVariance;

    @Column(nullable = false, length = 20)
    private String status;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        this.createdAt = Instant.now();
    }
}
