package com.katasticho.erp.partnernetwork.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record PlaceNetworkOrderRequest(
    UUID tradingPartnerId,
    LocalDate requestedDeliveryDate,
    String buyerNotes,
    List<LineRequest> lines
) {
    public record LineRequest(
        UUID catalogItemId,
        UUID buyerItemId,
        BigDecimal quantity,
        BigDecimal unitPrice
    ) {}
}
