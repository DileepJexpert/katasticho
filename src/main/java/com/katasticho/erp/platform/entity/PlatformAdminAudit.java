package com.katasticho.erp.platform.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "platform_admin_audit")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class PlatformAdminAudit {
    @Id @GeneratedValue(strategy = GenerationType.AUTO)
    private UUID id;
    @Column(name = "platform_admin_id", nullable = false) private UUID platformAdminId;
    @Column(name = "action_type", nullable = false, length = 50) private String actionType;
    @Column(name = "target_type", length = 20) private String targetType;
    @Column(name = "target_id") private UUID targetId;
    @Column(name = "target_name") private String targetName;
    @Column private String reason;
    @Column(name = "ip_address", length = 45) private String ipAddress;
    @Column(name = "performed_at", nullable = false) @Builder.Default private Instant performedAt = Instant.now();
}
