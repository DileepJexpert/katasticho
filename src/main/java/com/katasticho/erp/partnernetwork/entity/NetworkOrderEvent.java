package com.katasticho.erp.partnernetwork.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

@Entity
@Table(name = "network_order_event")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class NetworkOrderEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "network_order_id", nullable = false)
    private UUID networkOrderId;

    @Column(name = "event_type", nullable = false)
    private String eventType;

    @Column(name = "actor_org_id", nullable = false)
    private UUID actorOrgId;

    @Column(name = "actor_user_id")
    private UUID actorUserId;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "payload", columnDefinition = "jsonb")
    private Map<String, Object> payload;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
    }
}
