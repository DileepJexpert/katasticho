package com.katasticho.erp.contact.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "contact")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Contact extends BaseEntity {

    @Column(name = "contact_type", nullable = false, length = 10)
    @Enumerated(EnumType.STRING)
    @Builder.Default
    private ContactType contactType = ContactType.CUSTOMER;

    @Column(name = "display_name", nullable = false)
    private String displayName;

    @Column(name = "company_name")
    private String companyName;

    @Column(name = "first_name", length = 100)
    private String firstName;

    @Column(name = "last_name", length = 100)
    private String lastName;

    @Column(name = "salutation", length = 20)
    private String salutation;

    // Tax identifiers
    @Column(length = 15)
    private String gstin;

    @Column(length = 10)
    private String pan;

    @Column(name = "tax_id", length = 50)
    private String taxId;

    @Column(name = "gst_treatment", length = 30)
    @Enumerated(EnumType.STRING)
    @Builder.Default
    private GstTreatment gstTreatment = GstTreatment.UNREGISTERED;

    @Column(name = "place_of_supply", length = 5)
    private String placeOfSupply;

    @Column(name = "msme_registered", nullable = false)
    @Builder.Default
    private boolean msmeRegistered = false;

    @Column(name = "msme_registration_no", length = 50)
    private String msmeRegistrationNo;

    // Contact channels
    @Column(length = 255)
    private String email;

    @Column(length = 30)
    private String phone;

    @Column(length = 30)
    private String mobile;

    @Column(length = 255)
    private String website;

    // Billing address
    @Column(name = "billing_address_line1")
    private String billingAddressLine1;

    @Column(name = "billing_address_line2")
    private String billingAddressLine2;

    @Column(name = "billing_city", length = 100)
    private String billingCity;

    @Column(name = "billing_state", length = 100)
    private String billingState;

    @Column(name = "billing_state_code", length = 5)
    private String billingStateCode;

    @Column(name = "billing_postal_code", length = 20)
    private String billingPostalCode;

    @Column(name = "billing_country", length = 2)
    @Builder.Default
    private String billingCountry = "IN";

    // Shipping address
    @Column(name = "shipping_address_line1")
    private String shippingAddressLine1;

    @Column(name = "shipping_address_line2")
    private String shippingAddressLine2;

    @Column(name = "shipping_city", length = 100)
    private String shippingCity;

    @Column(name = "shipping_state", length = 100)
    private String shippingState;

    @Column(name = "shipping_state_code", length = 5)
    private String shippingStateCode;

    @Column(name = "shipping_postal_code", length = 20)
    private String shippingPostalCode;

    @Column(name = "shipping_country", length = 2)
    @Builder.Default
    private String shippingCountry = "IN";

    // Financial
    @Column(nullable = false, length = 3)
    @Builder.Default
    private String currency = "INR";

    @Column(name = "payment_terms_days", nullable = false)
    @Builder.Default
    private int paymentTermsDays = 30;

    @Column(name = "credit_limit", nullable = false)
    @Builder.Default
    private BigDecimal creditLimit = BigDecimal.ZERO;

    @Column(name = "opening_balance", nullable = false)
    @Builder.Default
    private BigDecimal openingBalance = BigDecimal.ZERO;

    @Column(name = "outstanding_ar", nullable = false)
    @Builder.Default
    private BigDecimal outstandingAr = BigDecimal.ZERO;

    @Column(name = "outstanding_ap", nullable = false)
    @Builder.Default
    private BigDecimal outstandingAp = BigDecimal.ZERO;

    @Column(name = "default_price_list_id")
    private UUID defaultPriceListId;

    // TDS
    @Column(name = "tds_applicable", nullable = false)
    @Builder.Default
    private boolean tdsApplicable = false;

    @Column(name = "tds_section", length = 20)
    private String tdsSection;

    @Column(name = "tds_rate")
    private BigDecimal tdsRate;

    // Bank details
    @Column(name = "bank_name")
    private String bankName;

    @Column(name = "bank_account_no", length = 50)
    private String bankAccountNo;

    @Column(name = "bank_ifsc", length = 20)
    private String bankIfsc;

    @Column(name = "upi_id", length = 50)
    private String upiId;

    // Portal
    @Column(name = "portal_enabled", nullable = false)
    @Builder.Default
    private boolean portalEnabled = false;

    @Column(name = "portal_url", length = 500)
    private String portalUrl;

    private String notes;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;

    @OneToMany(mappedBy = "contact", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<ContactPerson> persons = new ArrayList<>();
}
