package com.katasticho.erp.payroll.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/**
 * Salary component definition — earnings, deductions, or employer contributions.
 * Org-scoped.
 */
@Entity
@Table(name = "salary_component")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SalaryComponent {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(nullable = false, length = 50)
    private String code;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(name = "component_type", nullable = false, length = 20)
    private String componentType;

    @Column(length = 30)
    private String taxability;

    @Column(name = "is_statutory")
    @Builder.Default
    private boolean statutory = false;

    @Column(name = "is_active")
    @Builder.Default
    private boolean active = true;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
    }
}
