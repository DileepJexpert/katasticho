package com.katasticho.erp.pos.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "pos_cash_expense")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PosRegisterExpense {

    @Id
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "register_id", nullable = false)
    private UUID registerId;

    @Column(nullable = false)
    private BigDecimal amount;

    @Column(nullable = false, length = 255)
    private String description;

    @Column(name = "expense_time", nullable = false)
    private Instant expenseTime;

    @Column(name = "recorded_by")
    private UUID recordedBy;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void prePersist() {
        if (id == null) id = UUID.randomUUID();
        if (expenseTime == null) expenseTime = Instant.now();
        createdAt = Instant.now();
    }
}
