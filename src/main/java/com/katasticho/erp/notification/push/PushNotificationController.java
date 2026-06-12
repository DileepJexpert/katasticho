package com.katasticho.erp.notification.push;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.context.TenantContext;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * Push notification token registry and admin send.
 *
 * <ul>
 *   <li>{@code POST /api/v1/notifications/push/register} — register a device token (any role)</li>
 *   <li>{@code DELETE /api/v1/notifications/push/unregister} — deactivate a token (any role)</li>
 *   <li>{@code POST /api/v1/notifications/push/send} — broadcast to org (OWNER/ADMIN only)</li>
 * </ul>
 */
@RestController
@RequestMapping("/api/v1/notifications/push")
@RequiredArgsConstructor
public class PushNotificationController {

    private final PushNotificationService pushNotificationService;

    /**
     * Register (or refresh) a device token for the current user.
     * Body: {@code { "token": "...", "platform": "ANDROID|IOS|WEB" }}
     */
    @PostMapping("/register")
    @PreAuthorize("isAuthenticated()")
    public ApiResponse<Void> register(@RequestBody Map<String, String> body) {
        String token = required(body, "token");
        String platform = body.getOrDefault("platform", "ANDROID");
        pushNotificationService.registerToken(
                TenantContext.getCurrentUserId(), token, platform);
        return ApiResponse.ok(null, "Push token registered");
    }

    /**
     * Deactivate a device token (sign-out or token-refresh).
     * Body: {@code { "token": "..." }}
     */
    @DeleteMapping("/unregister")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("isAuthenticated()")
    public void unregister(@RequestBody Map<String, String> body) {
        pushNotificationService.removeToken(required(body, "token"));
    }

    /**
     * Broadcast a notification to all active devices in the organisation.
     * Body: {@code { "title": "...", "body": "..." }}
     * Requires OWNER or ADMIN role.
     */
    @PostMapping("/send")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ApiResponse<Void> send(@RequestBody Map<String, String> body) {
        String title = required(body, "title");
        String msgBody = required(body, "body");
        pushNotificationService.sendToOrg(title, msgBody);
        return ApiResponse.ok(null, "Notification dispatched");
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private static String required(Map<String, String> body, String key) {
        String v = body == null ? null : body.get(key);
        if (v == null || v.isBlank()) {
            throw new com.katasticho.erp.common.exception.BusinessException(
                    "'" + key + "' is required", "PUSH_FIELD_REQUIRED",
                    org.springframework.http.HttpStatus.BAD_REQUEST);
        }
        return v;
    }
}
