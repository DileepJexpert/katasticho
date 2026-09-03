package com.katasticho.erp.franchise.dto;

import lombok.Builder;
import lombok.Data;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

@Data
@Builder
public class FranchiseNodeResponse {
    private UUID id;
    private String nodeCode;
    private String nodeName;
    private String nodeType;
    private UUID branchId;
    private String contactEmail;
    private String phone;
    private String city;
    private String stateCode;
    private BigDecimal royaltyRatePercent;
    private BigDecimal fixedMonthlyFee;
    private boolean active;
    private OffsetDateTime lastSyncAt;
    private OffsetDateTime createdAt;
}