package com.katasticho.erp.recurring.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CreateRecurringInvoiceRequest(
        @NotBlank(message = "Profile name is required")
        String profileName,

        @NotNull(message = "Customer is required")
        UUID contactId,

        @NotBlank(message = "Frequency is required")
        String frequency,

        @NotNull(message = "Start date is required")
        LocalDate startDate,

        LocalDate endDate,

        /**
         * Optional — defaults to {@code startDate} if omitted. This is
         * the date on which the scheduler will mint the FIRST invoice.
         */
        LocalDate nextInvoiceDate,

        Integer paymentTermsDays,

        Boolean autoSend,

        String currency,

        String notes,

        String terms,

        @NotEmpty(message = "At least one line item is required")
        @Valid
        List<RecurringLineItemRequest> lineItems
) {}
