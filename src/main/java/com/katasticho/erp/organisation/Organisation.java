package com.katasticho.erp.organisation;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

/**
 * Organisation (tenant) entity. This is the root of multi-tenancy.
 * Every other entity references org_id back to this table.
 *
 * NOTE: Organisation does NOT extend BaseEntity because it IS the org —
 * it doesn't have an org_id pointing to another org.
 */
@Entity
@Table(name = "organisation")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Organisation {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false)
    private String name;

    // -- Country & Currency (v3-ready from day 1) --

    @Column(name = "country_code", nullable = false, length = 2)
    @Builder.Default
    private String countryCode = "IN";

    @Column(name = "base_currency", nullable = false, length = 3)
    @Builder.Default
    private String baseCurrency = "INR";

    @Column(nullable = false, length = 50)
    @Builder.Default
    private String timezone = "Asia/Kolkata";

    @Column(name = "tax_regime", nullable = false, length = 30)
    @Builder.Default
    private String taxRegime = "INDIA_GST";

    @Column(name = "fiscal_year_start", nullable = false)
    @Builder.Default
    private Integer fiscalYearStart = 4; // April for India

    // -- India-specific tax ID (keep separate — has specific 15-char format) --
    @Column(length = 15)
    private String gstin;

    // -- Generic tax ID for non-India countries (KRA PIN, FIRS TIN, TRN) --
    @Column(name = "tax_id", length = 50)
    private String taxId;

    // -- India-specific for CGST/SGST determination --
    @Column(name = "state_code", length = 5)
    private String stateCode;

    // -- Generic sub-national region for state-level taxes --
    @Column(name = "region_code", length = 20)
    private String regionCode;

    // -- Business details --
    @Column(length = 50)
    private String industry;
    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private Boolean isDeleted = false;
    @Column(name = "plan_tier", length = 20)
    @Builder.Default
    private String planTier = "FREE_BETA";

    @Column(name = "address_line1")
    private String addressLine1;

    @Column(name = "address_line2")
    private String addressLine2;

    @Column(length = 100)
    private String city;

    @Column(length = 100)
    private String state;

    @Column(name = "postal_code", length = 20)
    private String postalCode;

    @Column(length = 20)
    private String phone;

    @Column
    private String email;

    @Column(name = "logo_url")
    private String logoUrl;

    // -- Lifecycle --
    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private Boolean isActive = true;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "created_by")
    private UUID createdBy;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
        this.updatedAt = Instant.now();
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
