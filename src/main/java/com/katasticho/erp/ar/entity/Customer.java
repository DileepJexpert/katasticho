package com.katasticho.erp.ar.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;

@Entity
@Table(name = "customer")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Customer extends BaseEntity {

    @Column(nullable = false)
    private String name;

    private String email;
    private String phone;

    @Column(length = 15)
    private String gstin;

    @Column(name = "tax_id", length = 50)
    private String taxId;

    @Column(length = 10)
    private String pan;

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

    @Column(name = "credit_limit")
    @Builder.Default
    private BigDecimal creditLimit = BigDecimal.ZERO;

    @Column(name = "payment_terms_days")
    @Builder.Default
    private Integer paymentTermsDays = 30;

    private String notes;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;
}
