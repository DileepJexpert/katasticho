package com.katasticho.erp.inventory.subcontracting.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Raw materials/components issued to Job Worker under Rule 45 Challan.
 */
@Entity
@Table(name = "job_work_issue_line")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class JobWorkIssueLine extends BaseEntity {

    @Column(name = "job_work_order_id", nullable = false)
    private UUID jobWorkOrderId;

    @Column(name = "challan_number", nullable = false, length = 50)
    private String challanNumber;

    @Column(name = "challan_date", nullable = false)
    private LocalDate challanDate;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "hsn_code", length = 20)
    private String hsnCode;

    @Column(name = "uom", nullable = false, length = 20)
    @Builder.Default
    private String uom = "PCS";

    @Column(name = "issued_quantity", nullable = false, precision = 15, scale = 4)
    @Builder.Default
    private BigDecimal issuedQuantity = BigDecimal.ZERO;

    @Column(name = "returned_quantity", nullable = false, precision = 15, scale = 4)
    @Builder.Default
    private BigDecimal returnedQuantity = BigDecimal.ZERO;

    @Column(name = "unit_rate", nullable = false, precision = 15, scale = 4)
    @Builder.Default
    private BigDecimal unitRate = BigDecimal.ZERO;

    @Column(name = "taxable_value", nullable = false, precision = 15, scale = 4)
    @Builder.Default
    private BigDecimal taxableValue = BigDecimal.ZERO;

    @Column(name = "gst_rate", nullable = false, precision = 5, scale = 2)
    @Builder.Default
    private BigDecimal gstRate = BigDecimal.ZERO;

    @Column(name = "nature_of_processing", length = 150)
    private String natureOfProcessing;
}
