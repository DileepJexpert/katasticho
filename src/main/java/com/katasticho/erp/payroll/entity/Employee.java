package com.katasticho.erp.payroll.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Employee master — org-scoped with soft delete.
 */
@Entity
@Table(name = "employee")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Employee {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    /** Optional link to the app login of this employee (attendance/leave source). */
    @Column(name = "user_id")
    private UUID userId;

    @Column(name = "employee_code", length = 50)
    private String employeeCode;

    @Column(name = "full_name", nullable = false, length = 255)
    private String fullName;

    @Column(length = 30)
    private String phone;

    @Column(length = 255)
    private String email;

    @Column(length = 100)
    private String designation;

    @Column(length = 100)
    private String department;

    @Column(name = "date_of_joining")
    private LocalDate dateOfJoining;

    @Column(name = "date_of_exit")
    private LocalDate dateOfExit;

    @Column(name = "employment_status", length = 20)
    @Builder.Default
    private String employmentStatus = "ACTIVE";

    @Column(name = "payment_mode", length = 20)
    private String paymentMode;

    @Column(name = "bank_account_name", length = 255)
    private String bankAccountName;

    @Column(name = "bank_account_number", length = 50)
    private String bankAccountNumber;

    @Column(name = "bank_ifsc", length = 20)
    private String bankIfsc;

    @Column(length = 20)
    private String pan;

    @Column(name = "aadhaar_last4", length = 4)
    private String aadhaarLast4;

    @Column(length = 50)
    private String uan;

    @Column(name = "esi_number", length = 50)
    private String esiNumber;

    @Column(name = "is_pf_applicable", nullable = false)
    @Builder.Default
    private boolean pfApplicable = false;

    @Column(name = "is_esi_applicable", nullable = false)
    @Builder.Default
    private boolean esiApplicable = false;

    @Column(name = "is_pt_applicable", nullable = false)
    @Builder.Default
    private boolean ptApplicable = false;

    @Column(name = "is_lwf_applicable", nullable = false)
    @Builder.Default
    private boolean lwfApplicable = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "is_deleted")
    @Builder.Default
    private boolean isDeleted = false;

    @OneToMany(mappedBy = "employee", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    @JsonIgnore
    private List<EmployeeSalaryStructure> salaryStructures = new ArrayList<>();

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
