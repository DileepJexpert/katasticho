package com.katasticho.erp.fieldsales.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/** Retail Chemist Prescription Audit header: one audit of a chemist's sales. */
@Entity
@Table(name = "rcpa_audit")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RcpaAudit {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "salesperson_id", nullable = false)
    private UUID salespersonId;

    @Column(name = "chemist_contact_id", nullable = false)
    private UUID chemistContactId;

    @Column(name = "audit_date", nullable = false)
    private LocalDate auditDate;

    @Column(name = "field_visit_id")
    private UUID fieldVisitId;

    @Column(columnDefinition = "text")
    private String remarks;

    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private boolean isDeleted = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "created_by")
    private UUID createdBy;

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
