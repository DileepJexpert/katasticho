package com.katasticho.erp.ar.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CreateInvoiceRequest(
        @NotNull(message = "Contact ID is required")
        UUID contactId,

        @NotNull(message = "Invoice date is required")
        LocalDate invoiceDate,

        LocalDate dueDate,

        String placeOfSupply,

        boolean reverseCharge,

        String notes,
        String termsAndConditions,

        @NotEmpty(message = "At least one line item is required")
        @Valid
        List<InvoiceLineRequest> lines
) {}
