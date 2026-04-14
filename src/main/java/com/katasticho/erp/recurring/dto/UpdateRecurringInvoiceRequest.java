package com.katasticho.erp.recurring.dto;

import jakarta.validation.Valid;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Partial-update DTO. Any non-null field is applied; passing a
 * non-null {@code lineItems} replaces the whole template payload.
 */
public record UpdateRecurringInvoiceRequest(
        String profileName,
        UUID contactId,
        String frequency,
        LocalDate startDate,
        LocalDate endDate,
        LocalDate nextInvoiceDate,
        Integer paymentTermsDays,
        Boolean autoSend,
        String currency,
        String notes,
        String terms,
        @Valid List<RecurringLineItemRequest> lineItems
) {}
