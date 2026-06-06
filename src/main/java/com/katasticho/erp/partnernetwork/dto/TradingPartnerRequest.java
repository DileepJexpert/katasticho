package com.katasticho.erp.partnernetwork.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record TradingPartnerRequest(
    UUID targetOrgId,
    String role,
    BigDecimal creditLimit,
    String paymentTerms,
    String deliveryTerms,
    String notes
) {}
