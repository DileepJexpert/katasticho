package com.katasticho.erp.franchise.dto;

import lombok.Data;
import java.math.BigDecimal;
import java.util.UUID;

@Data
public class FranchiseNodeRequest {
    private String nodeCode;
    private String nodeName;
    private String nodeType; // COCO, FOFO, FICO
    private UUID branchId;
    private String contactEmail;
    private String phone;
    private String city;
    private String stateCode;
    private BigDecimal royaltyRatePercent;
    private BigDecimal fixedMonthlyFee;
    private Boolean active;
}