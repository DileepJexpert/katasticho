package com.katasticho.erp.inventory.transit.dto;

import com.katasticho.erp.inventory.transit.entity.TransferOrderDispatch;
import com.katasticho.erp.inventory.transit.entity.TransferOrderTransitEvent;
import lombok.Builder;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Builder
public record TransferOrderDispatchResponse(
        UUID id,
        UUID orgId,
        UUID transferOrderId,
        String vehicleNumber,
        String driverName,
        String driverPhone,
        Instant dispatchedAt,
        Instant expectedDeliveryAt,
        Instant deliveredAt,
        String status,
        BigDecimal latitude,
        BigDecimal longitude,
        String lastLocationName,
        Instant lastPingAt,
        Instant createdAt,
        List<TransitEventResponse> events
) {
    public static TransferOrderDispatchResponse from(TransferOrderDispatch d) {
        return new TransferOrderDispatchResponse(
                d.getId(),
                d.getOrgId(),
                d.getTransferOrderId(),
                d.getVehicleNumber(),
                d.getDriverName(),
                d.getDriverPhone(),
                d.getDispatchedAt(),
                d.getExpectedDeliveryAt(),
                d.getDeliveredAt(),
                d.getStatus(),
                d.getLatitude(),
                d.getLongitude(),
                d.getLastLocationName(),
                d.getLastPingAt(),
                d.getCreatedAt(),
                d.getEvents() != null
                        ? d.getEvents().stream().map(TransitEventResponse::from).toList()
                        : List.of()
        );
    }
}