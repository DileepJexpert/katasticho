package com.katasticho.erp.notification.push;

import com.katasticho.erp.common.context.TenantContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * Push notification service — token registry + dispatch stub.
 *
 * <h3>How to enable Firebase Cloud Messaging</h3>
 * Set ONE of these properties (see {@link FcmClient}):
 * <pre>
 *   app.push.fcm.service-account-file=/path/to/service-account.json
 *   app.push.fcm.service-account-json={...}   # e.g. via env var
 * </pre>
 * Delivery uses the FCM HTTP v1 API with a locally-signed OAuth2 assertion —
 * no Firebase Admin SDK dependency. Stale device tokens (UNREGISTERED) are
 * deactivated automatically.
 *
 * Until FCM is configured this service fully manages the token registry and
 * logs dispatch attempts without throwing.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class PushNotificationService {

    private final PushTokenRepository pushTokenRepository;
    private final FcmClient fcmClient;

    // ── Token registry ──────────────────────────────────────────────────────

    /**
     * Register (or reactivate) a device token for the current user.
     * Idempotent — calling again with the same token is safe.
     *
     * @param userId   the user who owns the device
     * @param token    FCM / APNS / Web-Push registration token
     * @param platform ANDROID | IOS | WEB
     */
    @Transactional
    public PushToken registerToken(UUID userId, String token, String platform) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Optional<PushToken> existing =
                pushTokenRepository.findByOrgIdAndDeviceTokenAndIsDeletedFalse(orgId, token);

        if (existing.isPresent()) {
            PushToken pt = existing.get();
            pt.setActive(true);
            pt.setUserId(userId);
            pt.setPlatform(normalize(platform));
            return pushTokenRepository.save(pt);
        }

        PushToken pt = PushToken.builder()
                .userId(userId)
                .deviceToken(token)
                .platform(normalize(platform))
                .isActive(true)
                .build();
        pt.setOrgId(orgId);
        return pushTokenRepository.save(pt);
    }

    /**
     * Deactivate a device token (called when the user signs out or the app
     * receives a token-invalidated callback from the FCM provider).
     */
    @Transactional
    public void removeToken(String token) {
        UUID orgId = TenantContext.getCurrentOrgId();
        pushTokenRepository.findByOrgIdAndDeviceTokenAndIsDeletedFalse(orgId, token)
                .ifPresent(pt -> {
                    pt.setActive(false);
                    pushTokenRepository.save(pt);
                });
    }

    // ── Dispatch ────────────────────────────────────────────────────────────

    /**
     * Send a notification to all active devices of a specific user.
     *
     * @param userId the target user
     * @param title  notification title
     * @param body   notification body text
     * @param data   optional key-value data payload (may be null)
     */
    public void sendToUser(UUID userId, String title, String body, Map<String, String> data) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<PushToken> tokens =
                pushTokenRepository.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, userId);
        tokens.stream()
                .filter(PushToken::isActive)
                .forEach(pt -> dispatchToToken(pt, title, body, data));
    }

    /**
     * Broadcast to all active devices in the organisation (use sparingly).
     *
     * @param title notification title
     * @param body  notification body text
     */
    public void sendToOrg(String title, String body) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<PushToken> tokens =
                pushTokenRepository.findByOrgIdAndIsActiveTrueAndIsDeletedFalse(orgId);
        tokens.forEach(pt -> dispatchToToken(pt, title, body, null));
    }

    // ── Internal ────────────────────────────────────────────────────────────

    private void dispatchToToken(PushToken token, String title, String body,
                                  Map<String, String> data) {
        if (!fcmClient.isConfigured()) {
            log.info("push-notification[STUB] platform={} title='{}' body='{}' data={}",
                    token.getPlatform(), title, body, data);
            return;
        }
        FcmClient.SendResult result = fcmClient.send(token.getDeviceToken(), title, body, data);
        if (result == FcmClient.SendResult.UNREGISTERED) {
            token.setActive(false);
            pushTokenRepository.save(token);
            log.info("Deactivated stale push token {} for user {}", token.getId(), token.getUserId());
        }
    }

    private static String normalize(String platform) {
        if (platform == null) return "ANDROID";
        String p = platform.toUpperCase(java.util.Locale.ROOT);
        if (p.equals("IOS") || p.equals("WEB")) return p;
        return "ANDROID";
    }
}
