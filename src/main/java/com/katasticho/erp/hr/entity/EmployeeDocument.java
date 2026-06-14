package com.katasticho.erp.hr.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/** An employee document (ID/PAN/insurance/contract) with category + expiry. */
@Entity
@Table(name = "hr_employee_document")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EmployeeDocument {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "employee_user_id", nullable = false)
    private UUID employeeUserId;

    @Column(nullable = false, length = 40)
    @Builder.Default
    private String category = "OTHER";

    @Column(nullable = false, length = 200)
    private String title;

    @Column(name = "file_name", length = 255)
    private String fileName;

    @Column(name = "file_url", length = 1000)
    private String fileUrl;

    @Column(name = "file_type", length = 100)
    private String fileType;

    @Column(name = "file_size")
    private Long fileSize;

    @Column(name = "expiry_date")
    private LocalDate expiryDate;

    @Column(name = "attachment_id")
    private UUID attachmentId;

    @Column(name = "uploaded_by")
    private UUID uploadedBy;

    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private boolean isDeleted = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        this.createdAt = Instant.now();
    }
}
