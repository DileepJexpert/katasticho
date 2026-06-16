package com.katasticho.erp.asset.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/** A capitalised fixed asset with book (Companies Act) + income-tax depreciation. */
@Entity
@Table(name = "fixed_asset")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FixedAsset {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "asset_code", nullable = false, length = 40)
    private String assetCode;

    @Column(nullable = false, length = 200)
    private String name;

    @Column(length = 60)
    private String category;

    @Column(name = "acquisition_date", nullable = false)
    private LocalDate acquisitionDate;

    @Column(nullable = false, precision = 18, scale = 2)
    private BigDecimal cost;

    @Column(name = "residual_value", nullable = false, precision = 18, scale = 2)
    @Builder.Default
    private BigDecimal residualValue = BigDecimal.ZERO;

    /** SLM | WDV (book / Companies Act). */
    @Column(name = "book_method", nullable = false, length = 10)
    private String bookMethod;

    @Column(name = "book_useful_life_months")
    private Integer bookUsefulLifeMonths;

    @Column(name = "book_rate_pct", precision = 7, scale = 3)
    private BigDecimal bookRatePct;

    @Column(name = "accumulated_depreciation", nullable = false, precision = 18, scale = 2)
    @Builder.Default
    private BigDecimal accumulatedDepreciation = BigDecimal.ZERO;

    @Column(name = "it_block", length = 40)
    private String itBlock;

    @Column(name = "it_rate_pct", precision = 7, scale = 3)
    private BigDecimal itRatePct;

    @Column(name = "asset_account_code", length = 20)
    private String assetAccountCode;

    @Column(name = "accumulated_dep_account_code", length = 20)
    private String accumulatedDepAccountCode;

    @Column(name = "dep_expense_account_code", length = 20)
    private String depExpenseAccountCode;

    /** ACTIVE | DISPOSED. */
    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "ACTIVE";

    @Column(name = "disposal_date")
    private LocalDate disposalDate;

    @Column(name = "disposal_proceeds", precision = 18, scale = 2)
    private BigDecimal disposalProceeds;

    @Column(name = "source_bill_id")
    private UUID sourceBillId;

    @Column(columnDefinition = "text")
    private String notes;

    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private boolean isDeleted = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "created_by")
    private UUID createdBy;

    /** Book net value = cost − accumulated depreciation. */
    @Transient
    public BigDecimal bookValue() {
        return cost.subtract(accumulatedDepreciation == null ? BigDecimal.ZERO : accumulatedDepreciation);
    }

    @PrePersist
    void onCreate() {
        this.createdAt = Instant.now();
        this.updatedAt = Instant.now();
    }

    @PreUpdate
    void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
