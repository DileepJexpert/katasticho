package com.katasticho.erp.franchise.dto;

import lombok.Builder;
import lombok.Data;
import java.math.BigDecimal;
import java.util.UUID;

@Data
@Builder
public class FranchiseCatalogPolicyResponse {
    private UUID id;
    private boolean autoSyncNewItems;
    private boolean allowBranchPriceOverride;
    private BigDecimal maxDiscountFromMrpPercent;
    private BigDecimal minMarginPercent;
    private String syncMode;
}