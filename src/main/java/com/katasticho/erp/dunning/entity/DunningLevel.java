package com.katasticho.erp.dunning.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

/**
 * One escalating reminder stage. When an invoice is at least {@code daysOverdue}
 * days past due (instalment-aware), the dunning sweep fires the highest applicable
 * not-yet-sent level over its {@code channel} using {@code messageTemplate}
 * ({{customer}}/{{amount}}/{{days}}/{{invoiceNumber}}/{{dueDate}}/{{orgName}} placeholders).
 */
@Entity
@Table(name = "dunning_level")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DunningLevel extends BaseEntity {

    @Column(nullable = false)
    @Builder.Default
    private int seq = 0;

    @Column(nullable = false, length = 120)
    private String name;

    @Column(name = "days_overdue", nullable = false)
    @Builder.Default
    private int daysOverdue = 0;

    @Column(nullable = false, length = 12)
    @Builder.Default
    private String channel = "AI_INBOX";

    @Column(length = 200)
    private String subject;

    @Column(name = "message_template", columnDefinition = "TEXT")
    private String messageTemplate;

    @Column(nullable = false)
    @Builder.Default
    private boolean active = true;
}
