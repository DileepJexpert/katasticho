package com.katasticho.erp.sales.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CreateSalesOrderRequest(
        @NotNull(message = "Contact ID is required")
        UUID contactId,

        @NotEmpty(message = "At least one line item is required")
        @Valid
        List<SalesOrderLineRequest> lines,

        /** Defaults to today if null. */
        LocalDate orderDate,

        LocalDate expectedShipmentDate,
        String referenceNumber,

        /** ITEM_LEVEL or ENTITY_LEVEL. */
        String discountType,

        /** Applicable when discountType is ENTITY_LEVEL. */
        BigDecimal discountAmount,

        BigDecimal shippingCharge,
        BigDecimal adjustment,
        String adjustmentDescription,
        String deliveryMethod,
        String placeOfSupply,
        String notes,
        String terms,

        /** JSON string representing the billing address. */
        String billingAddress,

        /** JSON string representing the shipping address. */
        String shippingAddress
) {}
