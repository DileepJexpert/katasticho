package com.katasticho.erp.partnernetwork.dto;

import com.katasticho.erp.partnernetwork.entity.TradingPartner;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record TradingPartnerResponse(
    UUID id,
    UUID sellerOrgId,
    UUID buyerOrgId,
    String sellerOrgName,
    String buyerOrgName,
    String status,
    UUID requestedByOrgId,
    BigDecimal creditLimit,
    String paymentTerms,
    String deliveryTerms,
    String notes,
    Instant createdAt,
    Instant approvedAt
) {
    public static TradingPartnerResponse from(TradingPartner tp, String sellerName, String buyerName) {
        return new TradingPartnerResponse(
            tp.getId(), tp.getSellerOrgId(), tp.getBuyerOrgId(),
            sellerName, buyerName,
            tp.getStatus(), tp.getRequestedByOrgId(),
            tp.getCreditLimit(), tp.getPaymentTerms(), tp.getDeliveryTerms(),
            tp.getNotes(), tp.getCreatedAt(), tp.getApprovedAt()
        );
    }
}
