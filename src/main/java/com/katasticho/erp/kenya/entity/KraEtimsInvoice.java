package com.katasticho.erp.kenya.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "kra_etims_invoice")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class KraEtimsInvoice extends BaseEntity {

    @Column(name = "invoice_id", nullable = false)
    private UUID invoiceId;

    @Column(name = "control_unit_number", nullable = false, length = 50)
    private String controlUnitNumber;

    @Column(name = "scu_receipt_number", nullable = false, length = 100)
    private String scuReceiptNumber;

    @Column(name = "qr_code_url", nullable = false, columnDefinition = "TEXT")
    private String qrCodeUrl;

    @Column(name = "status", nullable = false, length = 30)
    @Builder.Default
    private String status = "VERIFIED"; // PENDING, SUBMITTED, VERIFIED, REJECTED

    @Column(name = "response_payload", columnDefinition = "TEXT")
    private String responsePayload;

    @Column(name = "submitted_at", nullable = false)
    @Builder.Default
    private Instant submittedAt = Instant.now();
}