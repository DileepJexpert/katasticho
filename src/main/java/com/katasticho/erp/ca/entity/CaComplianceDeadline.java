package com.katasticho.erp.ca.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "ca_compliance_deadline")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CaComplianceDeadline {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "ca_client_link_id", nullable = false)
    private UUID caClientLinkId;

    @Column(name = "client_org_id", nullable = false)
    private UUID clientOrgId;

    @Column(name = "deadline_type", nullable = false, length = 50)
    private String deadlineType;

    @Column(name = "period_label", nullable = false, length = 20)
    private String periodLabel;

    @Column(name = "due_date", nullable = false)
    private LocalDate dueDate;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "PENDING";

    @Column(name = "filed_at")
    private Instant filedAt;

    @Column(name = "filed_by")
    private UUID filedBy;

    @Column(name = "filing_reference", length = 100)
    private String filingReference;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    void onCreate() {
        Instant now = Instant.now();
        createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = Instant.now();
    }
}
