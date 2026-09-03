package com.katasticho.erp.banking.reconciliation.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.*;

import java.util.UUID;

@Entity
@Table(name = "bank_reconciliation_rule")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BankReconciliationRule extends BaseEntity {

    @Column(name = "rule_name", nullable = false, length = 100)
    private String ruleName;

    @Column(name = "match_field", nullable = false, length = 50)
    @Builder.Default
    private String matchField = "DESCRIPTION"; // DESCRIPTION, REFERENCE, AMOUNT

    @Column(name = "operator", nullable = false, length = 30)
    @Builder.Default
    private String operator = "CONTAINS"; // CONTAINS, STARTS_WITH, REGEX, EXACT

    @Column(name = "match_pattern", nullable = false, length = 255)
    private String matchPattern;

    @Column(name = "target_account_id")
    private UUID targetAccountId;

    @Column(name = "auto_post", nullable = false)
    @Builder.Default
    private boolean autoPost = false;

    @Column(name = "priority", nullable = false)
    @Builder.Default
    private int priority = 10;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;
}