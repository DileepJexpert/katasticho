package com.katasticho.erp.franchise.dto;

import lombok.Data;
import java.time.LocalDate;
import java.util.UUID;

@Data
public class FranchiseRoyaltySettlementRequest {
    private UUID franchiseNodeId;
    private LocalDate periodStart;
    private LocalDate periodEnd;
}