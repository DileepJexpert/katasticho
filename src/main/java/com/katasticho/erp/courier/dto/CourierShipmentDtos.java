package com.katasticho.erp.courier.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** Request/response DTOs for the courier module. */
public class CourierShipmentDtos {

    public record CreateCourierShipmentRequest(
            UUID deliveryChallanId,
            UUID invoiceId,
            @NotNull UUID contactId,
            @NotBlank String courierPartner,   // BLUEDART | DELHIVERY | INDIA_POST | DTDC | SHIPROCKET | OTHER
            String courierService,
            String awbNumber,                  // optional if booking via the courier API
            boolean cod,
            BigDecimal codAmount,
            BigDecimal freightAmount,
            BigDecimal codFee,
            UUID transporterContactId,
            BigDecimal weightKg,
            BigDecimal declaredValue,
            String pickupAddress,
            String deliveryAddress,
            String notes
    ) {}

    public record RecordEventRequest(
            @NotBlank String eventStatus,      // PICKED_UP | IN_TRANSIT | OUT_FOR_DELIVERY | DELIVERED | RTO_INITIATED | RTO_DELIVERED | EXCEPTION
            Instant eventAt,
            String location,
            String rawPayload,
            String source                       // WEBHOOK | POLL | MANUAL — defaults to MANUAL
    ) {}

    public record CourierShipmentResponse(
            UUID id,
            String courierShipmentNumber,
            UUID deliveryChallanId,
            UUID invoiceId,
            UUID contactId,
            String courierPartner,
            String courierService,
            String awbNumber,
            String status,
            boolean cod,
            BigDecimal codAmount,
            UUID codRemittanceLineId,
            BigDecimal freightAmount,
            BigDecimal codFee,
            UUID transporterContactId,
            BigDecimal weightKg,
            BigDecimal declaredValue,
            Instant bookedAt,
            Instant deliveredAt,
            Instant rtoInitiatedAt,
            Instant rtoDeliveredAt,
            String notes,
            List<EventResponse> events
    ) {}

    public record EventResponse(
            UUID id,
            String eventStatus,
            Instant eventAt,
            String location,
            String source
    ) {}

    private CourierShipmentDtos() {}
}
