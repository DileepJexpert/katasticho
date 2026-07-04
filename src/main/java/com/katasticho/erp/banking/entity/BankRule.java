package com.katasticho.erp.banking.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * A user-defined bank-matching rule: when an imported transaction satisfies the
 * direction / narration / amount conditions, categorise it to {@code accountCode}
 * (optionally with a {@code contactId} + {@code memo}). Rules are evaluated in
 * ascending {@code priority}; the first match wins and is either shown as a
 * high-confidence suggestion or auto-applied (posting a direct bank↔account journal).
 */
@Entity
@Table(name = "bank_rule")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BankRule extends BaseEntity {

    @Column(nullable = false, length = 150)
    private String name;

    @Column(nullable = false)
    @Builder.Default
    private int priority = 100;

    @Column(nullable = false)
    @Builder.Default
    private boolean active = true;

    @Column(name = "direction_filter", nullable = false, length = 10)
    @Builder.Default
    private String directionFilter = "ANY";

    @Column(name = "narration_op", nullable = false, length = 12)
    @Builder.Default
    private String narrationOp = "CONTAINS";

    @Column(name = "narration_value", columnDefinition = "TEXT")
    private String narrationValue;

    @Column(name = "amount_op", nullable = false, length = 6)
    @Builder.Default
    private String amountOp = "ANY";

    @Column(name = "amount_value", precision = 18, scale = 2)
    private BigDecimal amountValue;

    @Column(name = "account_code", nullable = false, length = 40)
    private String accountCode;

    @Column(name = "contact_id")
    private UUID contactId;

    @Column(length = 255)
    private String memo;

    @Column(name = "auto_apply", nullable = false)
    @Builder.Default
    private boolean autoApply = false;
}
