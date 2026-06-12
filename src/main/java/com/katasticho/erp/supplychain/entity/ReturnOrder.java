package com.katasticho.erp.supplychain.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "return_order")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ReturnOrder extends BaseEntity {

    @Column(name = "return_number", nullable = false, length = 30)
    private String returnNumber;

    @Column(name = "return_type", nullable = false, length = 20)
    @Builder.Default
    private String returnType = "PURCHASE_RETURN";

    @Column(length = 20, nullable = false)
    @Builder.Default
    private String status = "DRAFT";

    @Column(name = "contact_id")
    private UUID contactId;

    @Column(name = "original_reference_id")
    private UUID originalReferenceId;

    @Column(name = "original_reference_type", length = 30)
    private String originalReferenceType;

    @Column(name = "warehouse_id")
    private UUID warehouseId;

    @Column(name = "reason_code", length = 30)
    private String reasonCode;

    @Column(name = "reason_notes", columnDefinition = "TEXT")
    private String reasonNotes;

    @Column(name = "total_amount", nullable = false)
    @Builder.Default
    private BigDecimal totalAmount = BigDecimal.ZERO;

    @Column(name = "restock_fee", nullable = false)
    @Builder.Default
    private BigDecimal restockFee = BigDecimal.ZERO;

    @Column(name = "net_refund", nullable = false)
    @Builder.Default
    private BigDecimal netRefund = BigDecimal.ZERO;

    @Column(name = "approved_by")
    private UUID approvedBy;

    @Column(name = "approved_at")
    private Instant approvedAt;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @OneToMany(mappedBy = "returnOrder", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<ReturnOrderLine> lines = new ArrayList<>();
}
