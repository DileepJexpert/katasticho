package com.katasticho.erp.inventory.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "generic_substitution")
@Getter
@Setter
@NoArgsConstructor
public class GenericSubstitution {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "drug_master_id", nullable = false)
    private UUID drugMasterId;

    @Column(name = "substitute_drug_master_id", nullable = false)
    private UUID substituteDrugMasterId;

    @Column(length = 255)
    private String reason;

    @Column(name = "estimated_savings", precision = 15, scale = 2)
    private BigDecimal estimatedSavings;

    @Column(name = "is_active", nullable = false)
    private boolean active = true;

    @Column(name = "created_at", nullable = false, updatable = false,
            insertable = false, columnDefinition = "TIMESTAMPTZ DEFAULT NOW()")
    private Instant createdAt;
}
