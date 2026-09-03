package com.katasticho.erp.franchise.dto;

import lombok.Data;
import java.math.BigDecimal;
import java.util.UUID;

@Data
public class BranchPriceOverrideRequest {
    private UUID branchId;
    private UUID itemId;
    private BigDecimal customSellingPrice;
    private BigDecimal customMrp;
    private BigDecimal minRetailPrice;
    private Boolean overrideActive;
}