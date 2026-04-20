package com.katasticho.erp.common.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "org_bootstrap_status")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OrgBootstrapStatus {

    @Id
    @Column(name = "org_id")
    private UUID orgId;

    @Column(name = "uoms_seeded_at")
    private Instant uomsSeededAt;

    @Column(name = "accounts_seeded_at")
    private Instant accountsSeededAt;

    @Column(name = "default_accounts_seeded_at")
    private Instant defaultAccountsSeededAt;

    @Column(name = "tax_config_seeded_at")
    private Instant taxConfigSeededAt;

    @Column(name = "last_bootstrap_at")
    private Instant lastBootstrapAt;

    @Column(name = "last_bootstrap_status")
    private String lastBootstrapStatus;

    @Column(name = "last_error_message")
    private String lastErrorMessage;

    @Column(name = "onboarding_completed", nullable = false)
    @Builder.Default
    private boolean onboardingCompleted = false;
}
