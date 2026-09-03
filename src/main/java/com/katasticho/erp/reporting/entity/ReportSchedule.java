package com.katasticho.erp.reporting.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "report_schedule")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReportSchedule {

    @Id
    @Column(name = "id", updatable = false, nullable = false)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "saved_report_id", nullable = false)
    private UUID savedReportId;

    /** DAILY / WEEKLY / MONTHLY */
    @Column(name = "frequency", nullable = false)
    private String frequency;

    /** 0=Sunday … 6=Saturday; only meaningful for WEEKLY */
    @Column(name = "day_of_week")
    private Short dayOfWeek;

    /** 1–31; only meaningful for MONTHLY */
    @Column(name = "day_of_month")
    private Short dayOfMonth;

    /** HH:MM in org local time */
    @Column(name = "send_time", nullable = false)
    private String sendTime;

    /** JSON array of email addresses */
    @Column(name = "recipient_emails", nullable = false, columnDefinition = "TEXT")
    private String recipientEmails;

    @Column(name = "subject_template")
    private String subjectTemplate;

    @Column(name = "is_active")
    private boolean active;

    @Column(name = "last_sent_at")
    private OffsetDateTime lastSentAt;

    @Column(name = "next_run_at")
    private OffsetDateTime nextRunAt;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;

    @PrePersist
    void prePersist() {
        if (id == null) id = UUID.randomUUID();
    }
}
