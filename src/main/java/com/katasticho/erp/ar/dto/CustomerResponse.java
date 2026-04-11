package com.katasticho.erp.ar.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record CustomerResponse(
        UUID id,
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
        boolean active,
        Instant createdAt
) {}
