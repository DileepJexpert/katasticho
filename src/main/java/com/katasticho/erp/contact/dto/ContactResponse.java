package com.katasticho.erp.contact.dto;

import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.entity.GstTreatment;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record ContactResponse(
        UUID id,
        ContactType contactType,
        String displayName,
        String companyName,
        String firstName,
        String lastName,
        String gstin,
        String pan,
        GstTreatment gstTreatment,
        String placeOfSupply,
        String email,
        String phone,
        String mobile,
        String website,

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

        String currency,
        int paymentTermsDays,
        BigDecimal creditLimit,
        BigDecimal openingBalance,
        BigDecimal outstandingAr,
        BigDecimal outstandingAp,
        UUID defaultPriceListId,

        boolean tdsApplicable,
        String tdsSection,
        BigDecimal tdsRate,

        String bankName,
        String bankAccountNo,
        String bankIfsc,
        String upiId,

        boolean active,
        String notes,
        Instant createdAt,
        List<ContactPersonResponse> persons
) {}
