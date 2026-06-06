package com.katasticho.erp.partnernetwork.dto;

import com.katasticho.erp.partnernetwork.entity.NetworkOrder;
import com.katasticho.erp.partnernetwork.entity.NetworkOrderLine;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record NetworkOrderResponse(
    UUID id,
    String orderNumber,
    UUID buyerOrgId,
    UUID sellerOrgId,
    String buyerOrgName,
    String sellerOrgName,
    UUID tradingPartnerId,
    UUID buyerPoId,
    UUID sellerSoId,
    String status,
    BigDecimal totalAmount,
    BigDecimal totalQty,
    LocalDate requestedDeliveryDate,
    String buyerNotes,
    String sellerNotes,
    Instant createdAt,
    Instant confirmedAt,
    Instant dispatchedAt,
    Instant deliveredAt,
    List<LineResponse> lines
) {
    public record LineResponse(
        UUID id,
        UUID catalogItemId,
        UUID buyerItemId,
        UUID sellerItemId,
        String displayName,
        String hsnCode,
        BigDecimal orderedQty,
        BigDecimal confirmedQty,
        BigDecimal dispatchedQty,
        BigDecimal unitPrice,
        BigDecimal lineTotal,
        String status,
        String sellerNotes
    ) {
        public static LineResponse from(NetworkOrderLine line) {
            return new LineResponse(
                line.getId(), line.getCatalogItemId(), line.getBuyerItemId(),
                line.getSellerItemId(), line.getDisplayName(), line.getHsnCode(),
                line.getOrderedQty(), line.getConfirmedQty(), line.getDispatchedQty(),
                line.getUnitPrice(), line.getLineTotal(), line.getStatus(),
                line.getSellerNotes()
            );
        }
    }

    public static NetworkOrderResponse from(NetworkOrder order, String buyerName, String sellerName) {
        return new NetworkOrderResponse(
            order.getId(), order.getOrderNumber(),
            order.getBuyerOrgId(), order.getSellerOrgId(),
            buyerName, sellerName,
            order.getTradingPartnerId(), order.getBuyerPoId(), order.getSellerSoId(),
            order.getStatus(), order.getTotalAmount(), order.getTotalQty(),
            order.getRequestedDeliveryDate(), order.getBuyerNotes(), order.getSellerNotes(),
            order.getCreatedAt(), order.getConfirmedAt(), order.getDispatchedAt(),
            order.getDeliveredAt(),
            order.getLines().stream().map(LineResponse::from).toList()
        );
    }
}
