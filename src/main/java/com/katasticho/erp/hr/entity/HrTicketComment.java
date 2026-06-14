package com.katasticho.erp.hr.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/** A comment in an HR help-desk ticket thread. */
@Entity
@Table(name = "hr_ticket_comment")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class HrTicketComment {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "ticket_id", nullable = false)
    private UUID ticketId;

    @Column(name = "author_user_id", nullable = false)
    private UUID authorUserId;

    @Column(nullable = false, columnDefinition = "text")
    private String body;

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
