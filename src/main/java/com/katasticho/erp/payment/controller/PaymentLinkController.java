package com.katasticho.erp.payment.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.payment.dto.PaymentLinkResponse;
import com.katasticho.erp.payment.service.PaymentLinkService;
import com.katasticho.erp.payment.service.RazorpayClient;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Create + list payment-gateway links for an invoice, and read/write the
 * per-org Razorpay settings (secrets write-only/masked, mirroring GspController).
 */
@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class PaymentLinkController {

    private final PaymentLinkService paymentLinkService;
    private final RazorpayClient razorpayClient;
    private final OrgSettingsService orgSettingsService;

    @PostMapping("/invoices/{invoiceId}/payment-link")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<PaymentLinkResponse>> create(@PathVariable UUID invoiceId) {
        return ResponseEntity.ok(ApiResponse.ok(
                PaymentLinkResponse.of(paymentLinkService.createForInvoice(invoiceId)),
                "Payment link created"));
    }

    @GetMapping("/invoices/{invoiceId}/payment-links")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<PaymentLinkResponse>>> list(@PathVariable UUID invoiceId) {
        return ResponseEntity.ok(ApiResponse.ok(
                paymentLinkService.listForInvoice(invoiceId).stream()
                        .map(PaymentLinkResponse::of).toList()));
    }

    @GetMapping("/settings/razorpay")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getSettings() {
        UUID orgId = TenantContext.getCurrentOrgId();
        Map<String, Object> out = new java.util.LinkedHashMap<>(razorpayClient.settings(orgId));
        // Surface the ready-to-paste webhook token (mint on first read).
        out.put("webhookToken", razorpayClient.ensureWebhookToken(orgId));
        return ResponseEntity.ok(ApiResponse.ok(out));
    }

    @PutMapping("/settings/razorpay")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> updateSettings(
            @RequestBody Map<String, Object> body) {
        UUID orgId = TenantContext.getCurrentOrgId();
        putIfPresent(orgId, body, "enabled", RazorpayClient.ENABLED);
        putIfPresent(orgId, body, "keyId", RazorpayClient.KEY_ID);
        putIfPresent(orgId, body, "baseUrl", RazorpayClient.BASE_URL);
        // Secrets: overwrite only when a non-blank value is supplied (never echoed).
        putSecretIfPresent(orgId, body, "keySecret", RazorpayClient.KEY_SECRET);
        putSecretIfPresent(orgId, body, "webhookSecret", RazorpayClient.WEBHOOK_SECRET);
        return ResponseEntity.ok(ApiResponse.ok(razorpayClient.settings(orgId), "Razorpay settings saved"));
    }

    private void putIfPresent(UUID orgId, Map<String, Object> body, String key, String settingKey) {
        if (body.containsKey(key) && body.get(key) != null) {
            orgSettingsService.set(orgId, settingKey, body.get(key).toString());
        }
    }

    private void putSecretIfPresent(UUID orgId, Map<String, Object> body, String key, String settingKey) {
        Object v = body.get(key);
        if (v != null && !v.toString().isBlank()) {
            orgSettingsService.set(orgId, settingKey, v.toString());
        }
    }
}
