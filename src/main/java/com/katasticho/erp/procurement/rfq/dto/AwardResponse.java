package com.katasticho.erp.procurement.rfq.dto;

import com.katasticho.erp.procurement.dto.PurchaseOrderResponse;

import java.util.UUID;

public record AwardResponse(
        UUID rfqId,
        UUID winningQuoteId,
        PurchaseOrderResponse purchaseOrder
) {}
