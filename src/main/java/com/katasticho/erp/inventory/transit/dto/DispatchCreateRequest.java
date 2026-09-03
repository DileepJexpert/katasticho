package com.katasticho.erp.inventory.transit.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DispatchCreateRequest {

    @NotNull(message = "Transfer order ID is required")
    private UUID transferOrderId;

    @NotBlank(message = "Vehicle number is required")
    private String vehicleNumber;

    @NotBlank(message = "Driver name is required")
    private String driverName;

    private String driverPhone;
    private Instant expectedDeliveryAt;
}