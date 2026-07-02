package com.katasticho.erp.payment.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.organisation.OrgSetting;
import com.katasticho.erp.organisation.OrgSettingsRepository;
import com.katasticho.erp.payment.service.PaymentLinkService;
import com.katasticho.erp.payment.service.RazorpayClient;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * Public Razorpay webhook receiver. Razorpay POSTs signed payment events here;
 * the per-org token in the URL path resolves which org the event belongs to
 * (permit-all in SecurityConfig — no JWT). Always returns 200 so Razorpay
 * doesn't retry-storm; the signature is verified per-org inside the service.
 *
 * <p>The raw body is taken as a String (NOT a parsed DTO) because the HMAC must
 * be computed over the exact bytes Razorpay signed.
 */
@RestController
@RequestMapping("/api/v1/webhooks/razorpay")
@RequiredArgsConstructor
@Slf4j
public class PaymentWebhookController {

    private final PaymentLinkService paymentLinkService;
    private final OrgSettingsRepository orgSettingsRepository;

    @PostMapping("/{orgToken}")
    public ResponseEntity<Map<String, Object>> receive(
            @PathVariable String orgToken,
            @RequestBody(required = false) String rawBody,
            @RequestHeader(value = "X-Razorpay-Signature", required = false) String signature,
            @RequestHeader(value = "X-Razorpay-Event-Id", required = false) String eventId) {

        Optional<UUID> orgId = resolveOrg(orgToken);
        if (orgId.isEmpty()) {
            // Permanent — a bad/rotated token never becomes valid on retry.
            log.warn("Razorpay webhook with unrecognised token");
            return ok(false, "unrecognised token");
        }
        try {
            TenantContext.setCurrentOrgId(orgId.get());
            TenantContext.setCurrentRole("SYSTEM");
            String status = paymentLinkService.handleWebhook(
                    orgId.get(), rawBody == null ? "" : rawBody, signature, eventId);
            return ok("recorded".equals(status), status);
        } catch (Exception e) {
            // Transient / unexpected failure — nothing was persisted (the whole
            // @Transactional rolled back, including the dedupe row), so answer
            // 5xx and let Razorpay retry rather than silently drop the payment.
            log.warn("Razorpay webhook processing error for org {}: {}", orgId.get(), e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("received", true, "applied", false, "status", "retry"));
        } finally {
            TenantContext.clear();
        }
    }

    private Optional<UUID> resolveOrg(String token) {
        if (token == null || token.isBlank()) return Optional.empty();
        return orgSettingsRepository
                .findFirstByKeyAndValue(RazorpayClient.WEBHOOK_TOKEN, token.trim())
                .map(OrgSetting::getOrgId);
    }

    private ResponseEntity<Map<String, Object>> ok(boolean applied, String status) {
        return ResponseEntity.ok(Map.of("received", true, "applied", applied, "status", status));
    }
}
