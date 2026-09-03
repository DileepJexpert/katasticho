package com.katasticho.erp.inventory.transit.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TransitPingRequest {

    @NotNull(message = "Latitude is required")
    private BigDecimal latitude;

    @NotNull(message = "Longitude is required")
    private BigDecimal longitude;

    @NotBlank(message = "Location name is required")
    private String locationName;

    @Builder.Default
    private String eventType = "CHECKPOINT"; // CHECKPOINT, DELAY_ALERT, DELIVERED

    private String eventNotes;
}