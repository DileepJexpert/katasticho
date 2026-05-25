package com.katasticho.erp.indent.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "customer_indent")
@Getter
@Setter
@NoArgsConstructor
public class CustomerIndent extends BaseEntity {

    @Column(name = "contact_id")
    private UUID contactId;

    @Column(name = "contact_name")
    private String contactName;

    @Column(name = "contact_phone")
    private String contactPhone;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "item_name", nullable = false)
    private String itemName;

    @Column(name = "sku")
    private String sku;

    @Column(name = "requested_qty", nullable = false)
    private BigDecimal requestedQty = BigDecimal.ONE;

    @Column(name = "unit")
    private String unit;

    @Column(name = "notes")
    private String notes;

    @Column(name = "status", nullable = false)
    private String status = "PENDING";

    @Column(name = "purchase_order_id")
    private UUID purchaseOrderId;

    @Column(name = "promised_date")
    private LocalDate promisedDate;

    @Column(name = "fulfilled_receipt_id")
    private UUID fulfilledReceiptId;

    @Column(name = "fulfilled_at")
    private Instant fulfilledAt;
}
