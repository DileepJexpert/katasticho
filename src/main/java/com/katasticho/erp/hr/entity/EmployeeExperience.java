package com.katasticho.erp.hr.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/** A prior employment record for the employee. */
@Entity
@Table(name = "hr_employee_experience")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EmployeeExperience {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "employee_id", nullable = false)
    private UUID employeeId;

    @Column(name = "company_name", nullable = false, length = 255)
    private String companyName;

    @Column(length = 150)
    private String designation;

    @Column(name = "from_date")
    private LocalDate fromDate;

    @Column(name = "to_date")
    private LocalDate toDate;

    @Column(length = 150)
    private String location;

    @Column(columnDefinition = "text")
    private String responsibilities;

    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private boolean isDeleted = false;

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
