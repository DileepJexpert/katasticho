package com.katasticho.erp.fieldsales.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "field_location_ping")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FieldLocationPing {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "salesperson_id", nullable = false)
    private UUID salespersonId;

    @Column(name = "route_execution_id")
    private UUID routeExecutionId;

    @Column(nullable = false, precision = 10, scale = 7)
    private BigDecimal latitude;

    @Column(nullable = false, precision = 10, scale = 7)
    private BigDecimal longitude;

    @Column(name = "accuracy_m", precision = 8, scale = 2)
    private BigDecimal accuracyM;

    @Column(name = "recorded_at", nullable = false)
    private Instant recordedAt;

    @Column(name = "created_at", nullable = false)
    @Builder.Default
    private Instant createdAt = Instant.now();
}
