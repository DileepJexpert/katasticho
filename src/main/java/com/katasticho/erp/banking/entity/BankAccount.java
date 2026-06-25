package com.katasticho.erp.banking.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * A business bank account (HDFC Current, SBI Savings, an OD/CC line, …). Each
 * one is its own ledger: {@code glAccountId} points at a GL sub-account under
 * Bank (1020) so a multi-bank org's cash movements stay separated. The single
 * default BANK account couldn't distinguish them.
 */
@Entity
@Table(name = "bank_account")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BankAccount {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false, updatable = false)
    private UUID orgId;

    @Column(name = "branch_id")
    private UUID branchId;

    @Column(nullable = false, length = 120)
    private String name;

    @Column(name = "bank_name", length = 120)
    private String bankName;

    @Column(name = "account_number", length = 40)
    private String accountNumber;

    @Column(length = 20)
    private String ifsc;

    @Column(length = 120)
    private String branch;

    /** SAVINGS | CURRENT | OD | CC | OTHER. */
    @Column(name = "account_type", nullable = false, length = 20)
    @Builder.Default
    private String accountType = "CURRENT";

    /** The GL ledger this bank account posts to (a sub-account of 1020). */
    @Column(name = "gl_account_id", nullable = false)
    private UUID glAccountId;

    @Column(name = "opening_balance", nullable = false)
    @Builder.Default
    private BigDecimal openingBalance = BigDecimal.ZERO;

    @Column(name = "is_default", nullable = false)
    @Builder.Default
    private boolean isDefault = false;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean isActive = true;

    private String notes;

    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private boolean isDeleted = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "created_by", updatable = false)
    private UUID createdBy;

    /** Resolved GL account code, set by the service (not persisted). */
    @Transient
    private String glAccountCode;

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
