package com.katasticho.erp.transport.dto;

import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/** Request/response DTOs for the transport (LR + freight) module. */
public class TransportDtos {

    // ── Freight rate cards ────────────────────────────────────────────────

    public record FreightRateCardRequest(
            @NotNull UUID transporterContactId,
            String origin,
            String destination,
            String mode,                 // ROAD | RAIL | AIR
            BigDecimal weightSlabMinKg,
            BigDecimal weightSlabMaxKg,
            String rateType,             // PER_KG | FLAT | PER_UNIT
            @NotNull BigDecimal rate,
            BigDecimal minCharge,
            LocalDate effectiveFrom,
            LocalDate effectiveTo,
            String notes
    ) {}

    public record FreightRateCardResponse(
            UUID id,
            UUID transporterContactId,
            String origin,
            String destination,
            String mode,
            BigDecimal weightSlabMinKg,
            BigDecimal weightSlabMaxKg,
            String rateType,
            BigDecimal rate,
            BigDecimal minCharge,
            LocalDate effectiveFrom,
            LocalDate effectiveTo,
            boolean active,
            String notes
    ) {}

    public record RateQuoteResponse(
            boolean found,
            UUID rateCardId,
            BigDecimal freightAmount,
            String basis,                // how it was computed, for transparency
            String message
    ) {}

    // ── Lorry receipts ────────────────────────────────────────────────────

    public record CreateLorryReceiptRequest(
            @NotNull LocalDate lrDate,
            @NotNull UUID transporterContactId,
            UUID contactId,
            UUID deliveryChallanId,
            UUID invoiceId,
            String ewayBillNo,
            String vehicleNumber,
            String driverName,
            String driverPhone,
            String origin,
            String destination,
            BigDecimal distanceKm,
            String mode,
            Integer numPackages,
            BigDecimal weightKg,
            BigDecimal declaredValue,
            BigDecimal freightAmount,    // if null and a rate card matches, it's auto-filled
            String freightBasis,         // PAID | TO_PAY | TO_BE_BILLED
            String gstTreatment,         // RCM | FORWARD | EXEMPT
            BigDecimal freightGstRate,
            String notes
    ) {}

    public record LorryReceiptResponse(
            UUID id,
            String lrNumber,
            LocalDate lrDate,
            UUID transporterContactId,
            UUID contactId,
            UUID deliveryChallanId,
            UUID invoiceId,
            String ewayBillNo,
            String vehicleNumber,
            String driverName,
            String driverPhone,
            String origin,
            String destination,
            BigDecimal distanceKm,
            String mode,
            Integer numPackages,
            BigDecimal weightKg,
            BigDecimal declaredValue,
            BigDecimal freightAmount,
            String freightBasis,
            String gstTreatment,
            BigDecimal freightGstRate,
            UUID freightBillId,
            String status,
            String notes
    ) {}

    public record BillFreightResult(
            UUID lorryReceiptId,
            UUID billId,
            String billNumber,
            BigDecimal freightAmount,
            boolean reverseCharge,
            String message
    ) {}

    private TransportDtos() {}
}
