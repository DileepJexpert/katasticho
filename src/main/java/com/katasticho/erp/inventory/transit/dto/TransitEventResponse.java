package com.katasticho.erp.inventory.transit.dto;

import com.katasticho.erp.inventory.transit.entity.TransferOrderTransitEvent;
import lombok.Builder;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Builder
public record TransitEventResponse(
        UUID id,
        String eventType,
        BigDecimal latitude,
        BigDecimal longitude,
        String locationName,
        String eventNotes,
        Instant recordedAt
) {
    public static TransitEventResponse from(TransferOrderTransitEvent e) {
        return new TransitEventResponse(
                e.getId(),
                e.getEventType(),
                e.getLatitude(),
                e.getLongitude(),
                e.getLocationName(),
                e.getEventNotes(),
                e.getRecordedAt()
        );
    }
}