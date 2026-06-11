package com.katasticho.erp.notification.sms;

import com.katasticho.erp.organisation.OrgSettingsService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;

/**
 * Provider-agnostic SMS service.
 * Supports Fast2SMS and MSG91. Configured per-org via org_settings keys:
 *   sms.enabled          true | false
 *   sms.provider         FAST2SMS | MSG91
 *   sms.api_key          provider API key
 *   sms.sender_id        6-char alphanumeric sender ID (MSG91 only)
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class SmsService {

    private final OrgSettingsService settingsService;

    private static final HttpClient HTTP = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            .build();

    // ── Public API ────────────────────────────────────────────────────────

    public void sendReceiptSms(UUID orgId, String phone, String receiptNumber,
                               BigDecimal total, String orgName) {
        if (!isEnabled(orgId)) return;
        String cleaned = sanitizePhone(phone);
        if (cleaned == null) return;

        String msg = String.format("Bill %s | Rs.%.0f | %s | Thank you! -Katasticho",
                receiptNumber, total, orgName);
        dispatchAsync(orgId, cleaned, msg);
    }

    public void sendLowStockAlert(UUID orgId, String ownerPhone, String itemName, double qty) {
        if (!isEnabled(orgId)) return;
        String cleaned = sanitizePhone(ownerPhone);
        if (cleaned == null) return;

        String msg = String.format("LOW STOCK: %s has only %.0f units remaining. Reorder now.",
                itemName, qty);
        dispatchAsync(orgId, cleaned, msg);
    }

    public boolean isEnabled(UUID orgId) {
        return "true".equalsIgnoreCase(settingsService.get(orgId, "sms.enabled", "false"));
    }

    // ── Internal ──────────────────────────────────────────────────────────

    private void dispatchAsync(UUID orgId, String phone, String message) {
        String provider = settingsService.get(orgId, "sms.provider", "FAST2SMS");
        String apiKey   = settingsService.get(orgId, "sms.api_key", null);
        String senderId = settingsService.get(orgId, "sms.sender_id", "KTSEPR");

        if (apiKey == null || apiKey.isBlank()) {
            log.debug("[SMS] api_key not configured for org {}", orgId);
            return;
        }

        CompletableFuture.runAsync(() -> {
            try {
                if ("MSG91".equalsIgnoreCase(provider)) {
                    sendMsg91(phone, message, apiKey, senderId);
                } else {
                    sendFast2Sms(phone, message, apiKey);
                }
                log.info("[SMS] Sent to {} via {} for org {}", phone, provider, orgId);
            } catch (Exception e) {
                log.warn("[SMS] Failed to send to {} via {}: {}", phone, provider, e.getMessage());
            }
        });
    }

    private void sendFast2Sms(String phone, String message, String apiKey) throws Exception {
        String body = """
                {"route":"q","message":"%s","numbers":"%s","flash":"0"}
                """.formatted(escape(message), phone).strip();

        HttpRequest req = HttpRequest.newBuilder()
                .uri(URI.create("https://www.fast2sms.com/dev/bulkV2"))
                .header("authorization", apiKey)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .timeout(Duration.ofSeconds(8))
                .build();

        HttpResponse<String> resp = HTTP.send(req, HttpResponse.BodyHandlers.ofString());
        if (resp.statusCode() != 200) {
            throw new RuntimeException("Fast2SMS returned HTTP " + resp.statusCode() + ": " + resp.body());
        }
    }

    private void sendMsg91(String phone, String message, String apiKey, String senderId) throws Exception {
        String body = """
                {"sender":"%s","route":"4","country":"91","sms":[{"message":"%s","to":["%s"]}]}
                """.formatted(senderId, escape(message), phone).strip();

        HttpRequest req = HttpRequest.newBuilder()
                .uri(URI.create("https://api.msg91.com/api/v2/sendsms"))
                .header("authkey", apiKey)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .timeout(Duration.ofSeconds(8))
                .build();

        HttpResponse<String> resp = HTTP.send(req, HttpResponse.BodyHandlers.ofString());
        if (resp.statusCode() != 200) {
            throw new RuntimeException("MSG91 returned HTTP " + resp.statusCode() + ": " + resp.body());
        }
    }

    /** Normalise to 10-digit Indian mobile number; returns null if not valid. */
    static String sanitizePhone(String raw) {
        if (raw == null) return null;
        String digits = raw.replaceAll("[^0-9]", "");
        if (digits.startsWith("91") && digits.length() == 12) digits = digits.substring(2);
        if (digits.startsWith("0") && digits.length() == 11) digits = digits.substring(1);
        if (digits.length() == 10 && digits.charAt(0) >= '6') return digits;
        return null;
    }

    private static String escape(String s) {
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", " ");
    }
}
