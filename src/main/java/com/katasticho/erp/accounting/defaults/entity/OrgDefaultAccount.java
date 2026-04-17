package com.katasticho.erp.accounting.defaults.entity;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "org_default_account",
       uniqueConstraints = @UniqueConstraint(columnNames = {"org_id", "purpose"}))
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class OrgDefaultAccount {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 40)
    private DefaultAccountPurpose purpose;

    @Column(name = "account_id", nullable = false)
    private UUID accountId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

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
