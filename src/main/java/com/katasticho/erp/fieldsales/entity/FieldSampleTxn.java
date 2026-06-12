package com.katasticho.erp.fieldsales.entity;

import com.katasticho.erp.common.context.TenantContext;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/** Sample / promo material issued to or returned by a field salesperson. */
@Entity
@Table(name = "field_sample_txn")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FieldSampleTxn {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "salesperson_id", nullable = false)
    private UUID salespersonId;

    @Column(name = "item_id")
    private UUID itemId;

    @Column(name = "product_name", nullable = false, length = 200)
    private String productName;

    /** ISSUE / RETURN. */
    @Column(name = "txn_type", nullable = false, length = 10)
    private String txnType;

    @Column(nullable = false)
    private int quantity;

    @Column(name = "txn_date", nullable = false)
    private LocalDate txnDate;

    private String notes;

    @Column(name = "created_by")
    private UUID createdBy;

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
