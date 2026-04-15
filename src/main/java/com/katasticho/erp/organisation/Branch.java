package com.katasticho.erp.organisation;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

/**
 * Branch — physical or logical business location under an organisation.
 * Every org has at least one default branch (created at signup). Warehouses,
 * users, invoices, payments, stock movements all carry branch_id so reports
 * can be rolled up per-branch. One branch per org is flagged is_default.
 */
@Entity
@Table(name = "branch")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Branch extends BaseEntity {

    @Column(nullable = false, length = 20)
    private String code;

    @Column(nullable = false)
    private String name;

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

    @Column(length = 15)
    private String gstin;

    @Column(name = "is_default", nullable = false)
    @Builder.Default
    private boolean isDefault = false;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;
}
