package com.katasticho.erp.common.currency.entity;

import jakarta.persistence.*;
import lombok.*;

import java.util.UUID;

/**
 * Platform-level currency catalogue.
 * NOT a BaseEntity — no org_id, shared across all tenants.
 */
@Entity
@Table(name = "currency")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Currency {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(length = 3, nullable = false, unique = true)
    private String code;

    @Column(length = 50, nullable = false)
    private String name;

    @Column(length = 5)
    private String symbol;

    @Column(name = "decimal_places", nullable = false)
    @Builder.Default
    private int decimalPlaces = 2;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean isActive = true;
}
