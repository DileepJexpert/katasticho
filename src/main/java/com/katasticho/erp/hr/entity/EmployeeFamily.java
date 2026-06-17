package com.katasticho.erp.hr.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/** Family member / dependent of a payroll employee. */
@Entity
@Table(name = "hr_employee_family")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EmployeeFamily {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "employee_id", nullable = false)
    private UUID employeeId;

    @Column(nullable = false, length = 150)
    private String name;

    @Column(nullable = false, length = 30)
    private String relationship;          // SPOUSE|CHILD|FATHER|MOTHER|SIBLING|OTHER

    @Column(name = "date_of_birth")
    private LocalDate dateOfBirth;

    @Column(name = "is_dependent", nullable = false)
    @Builder.Default
    private boolean dependent = false;

    @Column(length = 30)
    private String phone;

    @Column(columnDefinition = "text")
    private String notes;

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
