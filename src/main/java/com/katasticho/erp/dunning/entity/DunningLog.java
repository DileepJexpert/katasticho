package com.katasticho.erp.dunning.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Audit + idempotency row for a dunning notice. A partial unique index on
 * (org, invoice, level) WHERE outcome='SENT' guarantees each level fires at most
 * once per invoice; FAILED rows do not block a later retry.
 */
@Entity
@Table(name = "dunning_log")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DunningLog extends BaseEntity {

    @Column(name = "invoice_id", nullable = false)
    private UUID invoiceId;

    @Column(name = "contact_id")
    private UUID contactId;

    @Column(name = "dunning_level_id", nullable = false)
    private UUID dunningLevelId;

    @Column(name = "days_overdue", nullable = false)
    @Builder.Default
    private int daysOverdue = 0;

    @Column(nullable = false, precision = 18, scale = 2)
    @Builder.Default
    private BigDecimal amount = BigDecimal.ZERO;

    @Column(nullable = false, length = 12)
    private String channel;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String outcome = "SENT";

    @Column(columnDefinition = "TEXT")
    private String detail;

    @Column(name = "sent_at", nullable = false)
    @Builder.Default
    private Instant sentAt = Instant.now();
}
