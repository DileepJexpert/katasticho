package com.katasticho.erp.inventory.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "serial_number")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SerialNumber extends BaseEntity {

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(nullable = false, length = 100)
    private String serial;

    @Column(name = "warehouse_id")
    private UUID warehouseId;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "IN_STOCK";

    @Column(name = "batch_id")
    private UUID batchId;

    @Column(name = "received_at")
    private Instant receivedAt;

    @Column(name = "sold_at")
    private Instant soldAt;

    @Column(name = "receipt_line_id")
    private UUID receiptLineId;

    @Column(name = "invoice_line_id")
    private UUID invoiceLineId;

    @Column(columnDefinition = "TEXT")
    private String notes;
}
