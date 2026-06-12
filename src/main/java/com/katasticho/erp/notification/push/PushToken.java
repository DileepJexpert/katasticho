package com.katasticho.erp.notification.push;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.util.UUID;

/**
 * FCM / APNS / Web-Push device token registered by a user's client app.
 * One user may have multiple tokens (phone + tablet + web). Tokens are
 * soft-deleted (isActive = false) when the client unregisters.
 */
@Entity
@Table(name = "push_token",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_push_token_org_device",
                columnNames = {"org_id", "device_token"}))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PushToken extends BaseEntity {

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "device_token", nullable = false, columnDefinition = "TEXT")
    private String deviceToken;

    /** ANDROID | IOS | WEB */
    @Column(name = "platform", nullable = false, length = 10)
    private String platform;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean isActive = true;
}
