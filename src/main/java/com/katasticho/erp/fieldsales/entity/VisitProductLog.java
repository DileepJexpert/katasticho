package com.katasticho.erp.fieldsales.entity;

import com.katasticho.erp.common.context.TenantContext;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/** Product detailed / sample / gift given during a field visit (DCR line detail). */
@Entity
@Table(name = "visit_product_log")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class VisitProductLog {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "field_visit_id", nullable = false)
    private UUID fieldVisitId;

    @Column(name = "item_id")
    private UUID itemId;

    @Column(name = "product_name", nullable = false, length = 200)
    private String productName;

    @Column(nullable = false)
    @Builder.Default
    private boolean detailed = true;

    @Column(name = "sample_qty", nullable = false)
    @Builder.Default
    private int sampleQty = 0;

    @Column(name = "gift_name", length = 150)
    private String giftName;

    @Column(name = "gift_qty", nullable = false)
    @Builder.Default
    private int giftQty = 0;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
        if (this.orgId == null) {
            this.orgId = TenantContext.getCurrentOrgId();
        }
    }
}
