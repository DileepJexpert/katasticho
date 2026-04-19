package com.katasticho.erp.sales.dto;

import jakarta.validation.Valid;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Partial update of a DRAFT / CONFIRMED sales order. Nullable fields are left
 * untouched. If {@code lines} is non-null the entire line list is replaced.
 */
public record UpdateSalesOrderRequest(
        UUID contactId,

        @Valid
        List<SalesOrderLineRequest> lines,

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
