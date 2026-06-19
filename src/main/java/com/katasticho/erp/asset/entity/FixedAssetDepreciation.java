package com.katasticho.erp.asset.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/** One book-depreciation charge for an asset in a period. */
@Entity
@Table(name = "fixed_asset_depreciation")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FixedAssetDepreciation {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "fixed_asset_id", nullable = false)
    private UUID fixedAssetId;

    @Column(name = "period_year", nullable = false)
    private int periodYear;

    @Column(name = "period_month", nullable = false)
    private int periodMonth;

    @Column(name = "opening_wdv", nullable = false, precision = 18, scale = 2)
    private BigDecimal openingWdv;

    @Column(name = "depreciation_amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal depreciationAmount;

    @Column(name = "closing_wdv", nullable = false, precision = 18, scale = 2)
    private BigDecimal closingWdv;

    @Column(name = "journal_entry_id")
    private UUID journalEntryId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        this.createdAt = Instant.now();
    }
}
