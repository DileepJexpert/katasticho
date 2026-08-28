package com.katasticho.erp.notification.whatsapp;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/**
 * Audit row for a WhatsApp document send. One per attempt; status records the
 * outcome (SENT / FAILED / SKIPPED) and the provider's message id or error.
 */
@Entity
@Table(name = "whatsapp_message")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class WhatsAppMessage extends BaseEntity {

    @Column(name = "recipient", nullable = false, length = 20)
    private String recipient;

    @Column(name = "doc_type", nullable = false, length = 20)
    private String docType;

    @Column(name = "doc_id")
    private UUID docId;

    @Column(name = "template_name", length = 120)
    private String templateName;

    @Column(name = "status", nullable = false, length = 20)
    private String status;

    @Column(name = "provider", length = 20)
    private String provider;

    @Column(name = "provider_message_id", length = 120)
    private String providerMessageId;

    @Column(name = "error_message", columnDefinition = "TEXT")
    private String errorMessage;

    @Column(name = "sent_at")
    private Instant sentAt;

    @Column(name = "direction", length = 10)
    @Builder.Default
    private String direction = "OUTBOUND";

    @Column(name = "body", columnDefinition = "TEXT")
    private String body;
}
