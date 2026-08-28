package com.katasticho.erp.attendance.biometric.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

/**
 * Hardware Biometric Clock / Turnstile Device (ZKTeco, eSSL, Realtime, Anviz).
 */
@Entity
@Table(name = "biometric_device")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BiometricDevice extends BaseEntity {

    @Column(name = "device_name", nullable = false, length = 100)
    private String deviceName;

    @Column(name = "device_ip", length = 50)
    private String deviceIp;

    @Column(name = "port")
    @Builder.Default
    private Integer port = 4370;

    @Column(name = "serial_number", length = 100)
    private String serialNumber;

    @Column(name = "protocol", nullable = false, length = 20)
    @Builder.Default
    private String protocol = "ZK_TCP"; // ZK_TCP | ADMS_HTTP

    @Column(name = "location", length = 100)
    private String location;

    @Column(name = "status", nullable = false, length = 20)
    @Builder.Default
    private String status = "ONLINE"; // ONLINE | OFFLINE | SYNCING

    @Column(name = "last_sync_at")
    private Instant lastSyncAt;

    @Column(name = "cloud_webhook_token", length = 100)
    private String cloudWebhookToken;
}
