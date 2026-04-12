package com.katasticho.erp.procurement.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

/**
 * Minimal vendor master. Just enough to FK GRNs to a real entity from day one
 * so we don't end up with dirty free-text supplier names. Vendor bills,
 * payments, three-way matching land in v2 (AP module).
 */
@Entity
@Table(name = "supplier")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Supplier extends BaseEntity {

    @Column(nullable = false)
    private String name;

    @Column(length = 15)
    private String gstin;

    @Column(length = 10)
    private String pan;

    @Column(length = 30)
    private String phone;

    private String email;

    @Column(name = "address_line1")
    private String addressLine1;

    @Column(name = "address_line2")
    private String addressLine2;

    @Column(length = 100)
    private String city;

    @Column(length = 100)
    private String state;

    @Column(name = "state_code", length = 5)
    private String stateCode;

    @Column(name = "postal_code", length = 20)
    private String postalCode;

    @Column(length = 2)
    @Builder.Default
    private String country = "IN";

    @Column(name = "payment_terms_days", nullable = false)
    @Builder.Default
    private Integer paymentTermsDays = 30;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;
}
