package com.katasticho.erp.franchise.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "franchise_royalty_settlement")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FranchiseRoyaltySettlement extends BaseEntity {

    @Column(name = "franchise_node_id", nullable = false)
    private UUID franchiseNodeId;

    @Column(name = "period_start", nullable = false)
    private LocalDate periodStart;

    @Column(name = "period_end", nullable = false)
    private LocalDate periodEnd;

    @Column(name = "gross_sales_amount", precision = 15, scale = 2, nullable = false)
    @Builder.Default
    private BigDecimal grossSalesAmount = BigDecimal.ZERO;

    @Column(name = "royalty_percent", precision = 5, scale = 2, nullable = false)
    @Builder.Default
    private BigDecimal royaltyPercent = new BigDecimal("5.00");

    @Column(name = "royalty_amount", precision = 15, scale = 2, nullable = false)
    @Builder.Default
    private BigDecimal royaltyAmount = BigDecimal.ZERO;

    @Column(name = "fixed_fee_amount", precision = 15, scale = 2, nullable = false)
    @Builder.Default
    private BigDecimal fixedFeeAmount = BigDecimal.ZERO;

    @Column(name = "total_settlement_amount", precision = 15, scale = 2, nullable = false)
    @Builder.Default
    private BigDecimal totalSettlementAmount = BigDecimal.ZERO;

    @Column(nullable = false, length = 30)
    @Builder.Default
    private String status = "CALCULATED"; // DRAFT, CALCULATED, INVOICED, SETTLED

    @Column(name = "generated_invoice_id")
    private UUID generatedInvoiceId;
}