package com.katasticho.erp.procurement.rfq.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "supplier_quote")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SupplierQuote extends BaseEntity {

    @Column(name = "rfq_id", nullable = false)
    private UUID rfqId;

    @Column(name = "supplier_contact_id", nullable = false)
    private UUID supplierContactId;

    @Column(name = "quote_number", nullable = false, length = 30)
    private String quoteNumber;

    @Column(name = "valid_until")
    private LocalDate validUntil;

    @Column(name = "total_amount", nullable = false, precision = 15, scale = 2)
    @Builder.Default
    private BigDecimal totalAmount = BigDecimal.ZERO;

    @Column(nullable = false, length = 3)
    @Builder.Default
    private String currency = "INR";

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "RECEIVED";

    @Column(columnDefinition = "TEXT")
    private String notes;
}
