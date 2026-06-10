package com.katasticho.erp.gst.dto;

import com.katasticho.erp.gst.entity.EwayBill;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/** Request/response records for the e-way bill lifecycle. */
public final class EwayBillDtos {

    private EwayBillDtos() {}

    /** Manually flag a document (invoice / delivery challan) as needing an EWB. */
    public record CreateEwayBillRequest(
            @NotBlank String documentType,      // INVOICE / DELIVERY_CHALLAN
            @NotNull UUID documentId,
            String vehicleNumber,
            String transportMode,               // ROAD/RAIL/AIR/SHIP (default ROAD)
            String transporterId,
            String transporterName,
            Integer distanceKm
    ) {}

    /** Record the EWB number obtained on the NIC portal. */
    public record RecordEwbRequest(
            @NotBlank String ewbNumber,
            String vehicleNumber,
            Instant validUntil                  // computed from distance when null
    ) {}

    /** Vehicle-aggregate check: do the documents in this vehicle cross the threshold? */
    public record VehicleCheckRequest(
            @NotBlank String vehicleNumber,
            @NotNull LocalDate date,
            BigDecimal additionalValue          // value of a document about to be loaded
    ) {}

    public record EwayBillResponse(
            UUID id,
            String documentType,
            UUID documentId,
            String documentNumber,
            LocalDate documentDate,
            UUID contactId,
            BigDecimal totalValue,
            String status,
            String ewbNumber,
            String vehicleNumber,
            String transportMode,
            String transporterId,
            String transporterName,
            Integer distanceKm,
            String fromStateCode,
            String toStateCode,
            Instant generatedAt,
            Instant validUntil,
            Instant cancelledAt,
            String cancelReason
    ) {
        public static EwayBillResponse from(EwayBill e) {
            return new EwayBillResponse(
                    e.getId(), e.getDocumentType(), e.getDocumentId(), e.getDocumentNumber(),
                    e.getDocumentDate(), e.getContactId(), e.getTotalValue(), e.getStatus(),
                    e.getEwbNumber(), e.getVehicleNumber(), e.getTransportMode(),
                    e.getTransporterId(), e.getTransporterName(), e.getDistanceKm(),
                    e.getFromStateCode(), e.getToStateCode(),
                    e.getGeneratedAt(), e.getValidUntil(), e.getCancelledAt(), e.getCancelReason());
        }
    }
}
