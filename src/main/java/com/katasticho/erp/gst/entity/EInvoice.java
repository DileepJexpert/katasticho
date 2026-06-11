package com.katasticho.erp.gst.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/**
 * e-Invoice (IRN) lifecycle for a B2B sales invoice.
 *
 * <p>PENDING rows are auto-created when a posted invoice has a registered
 * (GSTIN) buyer and the org has e-invoicing enabled. We generate the IRP
 * INV-01 JSON; the IRN / acknowledgement / signed QR from the portal or GSP
 * is recorded back here.
 */
@Entity
@Table(name = "einvoice")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EInvoice extends BaseEntity {

    @Column(name = "invoice_id", nullable = false)
    private UUID invoiceId;

    @Column(name = "document_number", nullable = false, length = 50)
    private String documentNumber;

    @Column(name = "document_date", nullable = false)
    private LocalDate documentDate;

    @Column(name = "contact_id")
    private UUID contactId;

    @Column(name = "total_value", nullable = false)
    @Builder.Default
    private BigDecimal totalValue = BigDecimal.ZERO;

    /** PENDING → GENERATED → (CANCELLED). */
    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "PENDING";

    @Column(length = 64)
    private String irn;

    @Column(name = "ack_number", length = 30)
    private String ackNumber;

    @Column(name = "ack_date", length = 30)
    private String ackDate;

    @Column(name = "signed_qr", columnDefinition = "text")
    private String signedQr;

    @Column(name = "generated_at")
    private Instant generatedAt;

    @Column(name = "cancelled_at")
    private Instant cancelledAt;

    @Column(name = "cancel_reason", columnDefinition = "text")
    private String cancelReason;
}
