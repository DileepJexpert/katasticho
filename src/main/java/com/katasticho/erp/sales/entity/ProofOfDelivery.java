package com.katasticho.erp.sales.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Proof of Delivery — captured when goods are physically handed over.
 * Links to a delivery challan and/or an invoice (at least one required —
 * enforced at the DB level via the link CHECK in V21). Signature and
 * photo files are stored via {@code AttachmentService} with
 * {@code entityType = "POD"}.
 */
@Entity
@Table(name = "proof_of_delivery")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class ProofOfDelivery extends BaseEntity {

    @Column(name = "delivery_challan_id")
    private UUID deliveryChallanId;

    @Column(name = "invoice_id")
    private UUID invoiceId;

    @Column(name = "contact_id")
    private UUID contactId;

    @Column(name = "recipient_name", nullable = false, length = 150)
    private String recipientName;

    @Column(name = "recipient_phone", length = 30)
    private String recipientPhone;

    @Column(name = "recipient_relation", length = 50)
    private String recipientRelation;

    @Column(name = "delivered_at", nullable = false)
    private Instant deliveredAt;

    @Column(name = "geo_latitude", precision = 10, scale = 7)
    private BigDecimal geoLatitude;

    @Column(name = "geo_longitude", precision = 10, scale = 7)
    private BigDecimal geoLongitude;

    @Column(columnDefinition = "text")
    private String notes;

    @Column(name = "recorded_by")
    private UUID recordedBy;
}
