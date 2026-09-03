package com.katasticho.erp.franchise.dto;

import lombok.Builder;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

@Data
@Builder
public class FranchiseRoyaltySettlementResponse {
    private UUID id;
    private UUID franchiseNodeId;
    private String nodeCode;
    private String nodeName;
    private LocalDate periodStart;
    private LocalDate periodEnd;
    private BigDecimal grossSalesAmount;
    private BigDecimal royaltyPercent;
    private BigDecimal royaltyAmount;
    private BigDecimal fixedFeeAmount;
    private BigDecimal totalSettlementAmount;
    private String status;
    private UUID generatedInvoiceId;
    private OffsetDateTime createdAt;
}