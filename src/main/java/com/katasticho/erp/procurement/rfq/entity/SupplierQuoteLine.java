package com.katasticho.erp.procurement.rfq.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "supplier_quote_line")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SupplierQuoteLine extends BaseEntity {

    @Column(name = "supplier_quote_id", nullable = false)
    private UUID supplierQuoteId;

    @Column(name = "item_id")
    private UUID itemId;

    @Column(length = 500)
    private String description;

    @Column(nullable = false, precision = 15, scale = 4)
    private BigDecimal quantity;

    @Column(name = "unit_price", nullable = false, precision = 15, scale = 4)
    private BigDecimal unitPrice;

    @Column(name = "lead_time_days")
    private Integer leadTimeDays;

    @Column(length = 500)
    private String notes;
}
