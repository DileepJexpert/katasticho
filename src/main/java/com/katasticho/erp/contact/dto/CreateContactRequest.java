package com.katasticho.erp.contact.dto;

import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.entity.GstTreatment;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.UUID;

public record CreateContactRequest(
        @NotNull(message = "Contact type is required")
        ContactType contactType,

        @NotBlank(message = "Display name is required")
        String displayName,

        String companyName,
        String firstName,
        String lastName,
        String salutation,

        String gstin,
        String pan,
        String taxId,
        GstTreatment gstTreatment,
        String placeOfSupply,

        String email,
        String phone,
        String mobile,
        String website,

        // Billing address
        String billingAddressLine1,
        String billingAddressLine2,
        String billingCity,
        String billingState,
        String billingStateCode,
        String billingPostalCode,
        String billingCountry,

        // Shipping address
        String shippingAddressLine1,
        String shippingAddressLine2,
        String shippingCity,
        String shippingState,
        String shippingStateCode,
        String shippingPostalCode,
        String shippingCountry,

        String currency,
        Integer paymentTermsDays,
        BigDecimal creditLimit,
        BigDecimal openingBalance,
        UUID defaultPriceListId,

        // TDS (vendor)
        Boolean tdsApplicable,
        String tdsSection,
        BigDecimal tdsRate,

        // Bank details (vendor)
        String bankName,
        String bankAccountNo,
        String bankIfsc,
        String upiId,

        String notes
) {}
