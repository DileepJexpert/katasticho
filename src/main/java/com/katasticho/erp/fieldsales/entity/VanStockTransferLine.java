package com.katasticho.erp.fieldsales.entity;

import com.katasticho.erp.common.context.TenantContext;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "van_stock_transfer_line")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class VanStockTransferLine {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "van_stock_transfer_id", nullable = false)
    private UUID vanStockTransferId;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "batch_id")
    private UUID batchId;

    @Column(nullable = false)
    private BigDecimal quantity;

    @Column(length = 20)
    private String unit;

    private String notes;

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
