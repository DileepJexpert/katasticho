package com.katasticho.erp.supplychain.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "purchase_requisition")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PurchaseRequisition extends BaseEntity {

    @Column(name = "requisition_number", nullable = false, length = 30)
    private String requisitionNumber;

    @Column(length = 20, nullable = false)
    @Builder.Default
    private String status = "DRAFT";

    @Column(name = "requested_by")
    private UUID requestedBy;

    @Column(name = "approved_by")
    private UUID approvedBy;

    @Column(name = "approved_at")
    private Instant approvedAt;

    @Column(name = "required_by_date")
    private LocalDate requiredByDate;

    @Column(name = "supplier_id")
    private UUID supplierId;

    @Column(name = "warehouse_id")
    private UUID warehouseId;

    @Column(name = "total_amount", nullable = false)
    @Builder.Default
    private BigDecimal totalAmount = BigDecimal.ZERO;

    @Column(length = 30, nullable = false)
    @Builder.Default
    private String source = "MANUAL";

    @Column(name = "purchase_order_id")
    private UUID purchaseOrderId;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @OneToMany(mappedBy = "requisition", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<PurchaseRequisitionLine> lines = new ArrayList<>();
}
