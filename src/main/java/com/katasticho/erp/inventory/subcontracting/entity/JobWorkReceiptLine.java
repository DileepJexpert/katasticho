package com.katasticho.erp.inventory.subcontracting.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Processed/finished goods received back from Job Worker.
 */
@Entity
@Table(name = "job_work_receipt_line")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class JobWorkReceiptLine extends BaseEntity {

    @Column(name = "job_work_order_id", nullable = false)
    private UUID jobWorkOrderId;

    @Column(name = "inward_challan_number", nullable = false, length = 50)
    private String inwardChallanNumber;

    @Column(name = "receipt_date", nullable = false)
    private LocalDate receiptDate;

    @Column(name = "finished_item_id", nullable = false)
    private UUID finishedItemId;

    @Column(name = "uom", nullable = false, length = 20)
    @Builder.Default
    private String uom = "PCS";

    @Column(name = "received_quantity", nullable = false, precision = 15, scale = 4)
    @Builder.Default
    private BigDecimal receivedQuantity = BigDecimal.ZERO;

    @Column(name = "consumed_raw_item_id")
    private UUID consumedRawItemId;

    @Column(name = "consumed_quantity", nullable = false, precision = 15, scale = 4)
    @Builder.Default
    private BigDecimal consumedQuantity = BigDecimal.ZERO;

    @Column(name = "scrap_quantity", nullable = false, precision = 15, scale = 4)
    @Builder.Default
    private BigDecimal scrapQuantity = BigDecimal.ZERO;

    @Column(name = "job_work_charges", nullable = false, precision = 15, scale = 4)
    @Builder.Default
    private BigDecimal jobWorkCharges = BigDecimal.ZERO;

    @Column(name = "notes", length = 255)
    private String notes;
}
