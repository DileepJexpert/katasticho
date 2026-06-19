package com.katasticho.erp.transport.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** DTOs for the vehicle-log (TCO) and proof-of-delivery features. */
public class FleetDtos {

    // ── Vehicle log ───────────────────────────────────────────────────────

    public record VehicleLogRequest(
            @NotBlank String vehicleNumber,
            UUID vanId,
            @NotBlank String logType,        // FUEL | SERVICE | REPAIR | INSURANCE | FITNESS | PERMIT | TYRE | OTHER
            @NotNull LocalDate logDate,
            BigDecimal odometerKm,
            BigDecimal quantity,             // litres for FUEL
            @NotNull BigDecimal amount,
            UUID vendorContactId,
            String referenceNo,
            String notes
    ) {}

    public record VehicleLogResponse(
            UUID id,
            String vehicleNumber,
            UUID vanId,
            String logType,
            LocalDate logDate,
            BigDecimal odometerKm,
            BigDecimal quantity,
            BigDecimal amount,
            UUID vendorContactId,
            String referenceNo,
            String notes
    ) {}

    /**
     * Total-cost-of-ownership rollup for one vehicle:
     * total spend (+ by type), distance run (max−min odometer over the window),
     * ₹/km, and fuel mileage (km/litre).
     */
    public record VehicleTcoSummary(
            String vehicleNumber,
            BigDecimal totalSpend,
            Map<String, BigDecimal> spendByType,
            BigDecimal distanceKm,
            BigDecimal costPerKm,
            BigDecimal fuelLitres,
            BigDecimal mileageKmPerLitre,
            int entryCount
    ) {}

    // ── Proof of delivery ────────────────────────────────────────────────

    public record CreatePodRequest(
            UUID deliveryChallanId,
            UUID courierShipmentId,
            UUID invoiceId,
            UUID contactId,
            String recipientName,
            String recipientPhone,
            Instant deliveredAt,
            BigDecimal geoLatitude,
            BigDecimal geoLongitude,
            String notes
    ) {}

    public record PodResponse(
            UUID id,
            UUID deliveryChallanId,
            UUID courierShipmentId,
            UUID invoiceId,
            UUID contactId,
            String recipientName,
            String recipientPhone,
            Instant deliveredAt,
            BigDecimal geoLatitude,
            BigDecimal geoLongitude,
            String notes,
            List<PodAttachment> attachments
    ) {}

    public record PodAttachment(UUID id, String fileName, String fileUrl, Long fileSize) {}

    private FleetDtos() {}
}
