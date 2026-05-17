package com.katasticho.erp.ar.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "reminder_log")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ReminderLog {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "contact_id", nullable = false)
    private UUID contactId;

    @Column(name = "sent_at", nullable = false)
    private Instant sentAt;

    @Column(name = "channel", nullable = false, length = 20)
    @Builder.Default
    private String channel = "WHATSAPP";

    @Column(name = "message_preview")
    private String messagePreview;

    @Column(name = "sent_by")
    private UUID sentBy;

    @PrePersist
    protected void onCreate() {
        if (this.sentAt == null) {
            this.sentAt = Instant.now();
        }
    }
}
