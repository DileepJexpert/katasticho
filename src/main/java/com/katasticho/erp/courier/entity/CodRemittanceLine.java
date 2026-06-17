package com.katasticho.erp.courier.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * One COD parcel inside a {@link CodRemittance}. On settle:
 * <ul>
 *   <li><b>MATCHED</b> — the AWB resolves to a known {@link CourierShipment} →
 *       invoice; a Payment is posted (DR Bank/COD-control CR AR), the COD fee
 *       is booked as expense, and the shipment is stamped settled.</li>
 *   <li><b>AMOUNT_MISMATCH</b> — AWB resolves but {@code codAmount} differs from
 *       the invoice balance; the line is held for review.</li>
 *   <li><b>ORPHAN</b> — AWB not found in books; the line is surfaced as an
 *       exception (no posting), to be re-tried after the missing shipment is created.</li>
 * </ul>
 */
@Entity
@Table(name = "cod_remittance_line")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CodRemittanceLine {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "cod_remittance_id", nullable = false)
    private CodRemittance remittance;

    @Column(name = "awb_number", nullable = false, length = 60)
    private String awbNumber;

    @Column(name = "courier_shipment_id")
    private UUID courierShipmentId;

    @Column(name = "invoice_id")
    private UUID invoiceId;

    @Column(name = "cod_amount", nullable = false)
    private BigDecimal codAmount;

    @Column(name = "cod_fee", nullable = false)
    @Builder.Default
    private BigDecimal codFee = BigDecimal.ZERO;

    @Column(name = "net_amount", nullable = false)
    private BigDecimal netAmount;

    /** PENDING | MATCHED | AMOUNT_MISMATCH | ORPHAN */
    @Column(name = "match_status", nullable = false, length = 20)
    @Builder.Default
    private String matchStatus = "PENDING";

    @Column(name = "payment_id")
    private UUID paymentId;

    private String notes;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) createdAt = Instant.now();
    }
}
