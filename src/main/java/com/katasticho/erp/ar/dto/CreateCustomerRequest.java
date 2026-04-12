package com.katasticho.erp.ar.dto;

import jakarta.validation.constraints.NotBlank;

import java.math.BigDecimal;
import java.util.UUID;

public record CreateCustomerRequest(
        @NotBlank(message = "Customer name is required")
        String name,
        String email,
        String phone,
        String gstin,
        String taxId,
        String pan,
        String billingAddressLine1,
        String billingAddressLine2,
        String billingCity,
        String billingState,
        String billingStateCode,
        String billingPostalCode,
        String billingCountry,
        String shippingAddressLine1,
        String shippingAddressLine2,
        String shippingCity,
        String shippingState,
        String shippingStateCode,
        String shippingPostalCode,
        String shippingCountry,
        BigDecimal creditLimit,
        Integer paymentTermsDays,
        String notes,
        /** Optional — pins a price list to the customer. Resolved at
         *  invoice-create time; legacy callers who don't send it keep
         *  pre-F3 behaviour (org default → item.salePrice). */
        UUID defaultPriceListId
) {}
