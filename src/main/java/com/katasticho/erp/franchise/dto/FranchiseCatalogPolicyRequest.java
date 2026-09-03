package com.katasticho.erp.franchise.dto;

import lombok.Data;
import java.math.BigDecimal;

@Data
public class FranchiseCatalogPolicyRequest {
    private Boolean autoSyncNewItems;
    private Boolean allowBranchPriceOverride;
    private BigDecimal maxDiscountFromMrpPercent;
    private BigDecimal minMarginPercent;
    private String syncMode;
}