package com.katasticho.erp.courier.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/** Request/response DTOs for COD remittance ingest and reconciliation. */
public class CodRemittanceDtos {

    public record CreateCodRemittanceRequest(
            @NotBlank String courierPartner,
            @NotNull LocalDate remittanceDate,
            String bankAccount,
            String utr,
            BigDecimal netRemitted,
            String notes,
            @NotNull List<CodLineInput> lines
    ) {}

    public record CodLineInput(
            @NotBlank String awbNumber,
            @NotNull BigDecimal codAmount,
            BigDecimal codFee
    ) {}

    public record CodRemittanceResponse(
            UUID id,
            String remittanceNumber,
            String courierPartner,
            LocalDate remittanceDate,
            String bankAccount,
            String utr,
            BigDecimal grossCollected,
            BigDecimal totalFees,
            BigDecimal netRemitted,
            BigDecimal expectedNet,
            BigDecimal variance,
            String status,
            String notes,
            List<CodLineResponse> lines
    ) {}

    public record CodLineResponse(
            UUID id,
            String awbNumber,
            UUID courierShipmentId,
            UUID invoiceId,
            BigDecimal codAmount,
            BigDecimal codFee,
            BigDecimal netAmount,
            String matchStatus,
            UUID paymentId,
            String notes
    ) {}

    public record ReconcileResult(
            UUID remittanceId,
            int matched,
            int amountMismatch,
            int orphan,
            BigDecimal totalSettled,
            BigDecimal totalFees,
            BigDecimal variance
    ) {}

    private CodRemittanceDtos() {}
}
