package com.katasticho.erp.franchise.dto;

import lombok.Builder;
import lombok.Data;
import java.math.BigDecimal;
import java.util.UUID;

@Data
@Builder
public class BranchPriceOverrideResponse {
    private UUID id;
    private UUID branchId;
    private UUID itemId;
    private String itemSku;
    private String itemName;
    private BigDecimal masterSellingPrice;
    private BigDecimal masterMrp;
    private BigDecimal customSellingPrice;
    private BigDecimal customMrp;
    private BigDecimal effectiveMarginPercent;
    private boolean overrideActive;
}