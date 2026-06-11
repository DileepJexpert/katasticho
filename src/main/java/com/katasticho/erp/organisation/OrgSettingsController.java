package com.katasticho.erp.organisation;

import com.katasticho.erp.common.context.TenantContext;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/settings")
@RequiredArgsConstructor
@PreAuthorize("isAuthenticated()")
public class OrgSettingsController {

    private final OrgSettingsService settingsService;

    @GetMapping
    public ResponseEntity<Map<String, String>> getAll() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return ResponseEntity.ok(settingsService.getAll(orgId));
    }

    @PutMapping
    @PreAuthorize("hasRole('OWNER') or hasRole('ADMIN')")
    public ResponseEntity<Map<String, String>> updateAll(@RequestBody Map<String, String> settings) {
        UUID orgId = TenantContext.getCurrentOrgId();
        settingsService.setBulk(orgId, settings);
        return ResponseEntity.ok(settingsService.getAll(orgId));
    }

    @GetMapping("/{key}")
    public ResponseEntity<Map<String, String>> getOne(@PathVariable String key) {
        UUID orgId = TenantContext.getCurrentOrgId();
        String value = settingsService.get(orgId, key, null);
        if (value == null) return ResponseEntity.notFound().build();
        return ResponseEntity.ok(Map.of(key, value));
    }

    @PutMapping("/{key}")
    @PreAuthorize("hasRole('OWNER') or hasRole('ADMIN')")
    public ResponseEntity<Map<String, String>> setOne(
            @PathVariable String key,
            @RequestBody Map<String, String> body) {
        UUID orgId = TenantContext.getCurrentOrgId();
        String value = body.get("value");
        if (value == null) value = body.get(key);
        settingsService.set(orgId, key, value);
        return ResponseEntity.ok(Map.of(key, settingsService.get(orgId, key, "")));
    }

    @GetMapping("/upi")
    public ResponseEntity<Map<String, String>> getUpiSettings() {
        UUID orgId = TenantContext.getCurrentOrgId();
        String upiId = settingsService.get(orgId, "pos.upi_id", null);
        String displayName = settingsService.get(orgId, "pos.upi_display_name", null);
        Map<String, String> result = new java.util.HashMap<>();
        if (upiId != null) result.put("upiId", upiId);
        if (displayName != null) result.put("displayName", displayName);
        return ResponseEntity.ok(result);
    }

    @PutMapping("/upi")
    @PreAuthorize("hasRole('OWNER') or hasRole('ADMIN')")
    public ResponseEntity<Map<String, String>> updateUpiSettings(@RequestBody Map<String, String> body) {
        UUID orgId = TenantContext.getCurrentOrgId();
        String upiId = body.get("upiId");
        String displayName = body.get("displayName");
        if (upiId != null) settingsService.set(orgId, "pos.upi_id", upiId);
        if (displayName != null) settingsService.set(orgId, "pos.upi_display_name", displayName);
        return ResponseEntity.ok(body);
    }

    @GetMapping("/sms")
    public ResponseEntity<Map<String, String>> getSmsSettings() {
        UUID orgId = TenantContext.getCurrentOrgId();
        Map<String, String> result = new java.util.HashMap<>();
        result.put("enabled", settingsService.get(orgId, "sms.enabled", "false"));
        result.put("provider", settingsService.get(orgId, "sms.provider", "FAST2SMS"));
        String apiKey = settingsService.get(orgId, "sms.api_key", null);
        if (apiKey != null) result.put("apiKey", apiKey);
        result.put("senderId", settingsService.get(orgId, "sms.sender_id", "KTSEPR"));
        return ResponseEntity.ok(result);
    }

    @PutMapping("/sms")
    @PreAuthorize("hasRole('OWNER') or hasRole('ADMIN')")
    public ResponseEntity<Map<String, String>> updateSmsSettings(@RequestBody Map<String, String> body) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (body.containsKey("enabled")) settingsService.set(orgId, "sms.enabled", body.get("enabled"));
        if (body.containsKey("provider")) settingsService.set(orgId, "sms.provider", body.get("provider"));
        if (body.containsKey("apiKey")) settingsService.set(orgId, "sms.api_key", body.get("apiKey"));
        if (body.containsKey("senderId")) settingsService.set(orgId, "sms.sender_id", body.get("senderId"));
        return ResponseEntity.ok(body);
    }

    @GetMapping("/whatsapp")
    public ResponseEntity<Map<String, String>> getWhatsAppSettings() {
        UUID orgId = TenantContext.getCurrentOrgId();
        Map<String, String> result = new java.util.HashMap<>();
        result.put("enabled", settingsService.get(orgId, "whatsapp.enabled", "false"));
        result.put("provider", settingsService.get(orgId, "whatsapp.provider", "META"));
        result.put("phoneNumberId", settingsService.get(orgId, "whatsapp.phone_number_id", ""));
        result.put("customUrl", settingsService.get(orgId, "whatsapp.custom_url", ""));
        result.put("lang", settingsService.get(orgId, "whatsapp.lang", "en"));
        result.put("autoSendReceipt", settingsService.get(orgId, "whatsapp.auto_send_receipt", "false"));
        result.put("templateInvoice", settingsService.get(orgId, "whatsapp.template_invoice", ""));
        result.put("templateReceipt", settingsService.get(orgId, "whatsapp.template_receipt", ""));
        result.put("templateReminder", settingsService.get(orgId, "whatsapp.template_reminder", ""));
        result.put("templateStatement", settingsService.get(orgId, "whatsapp.template_statement", ""));
        // The access token is write-only: report whether one is set, never echo it.
        result.put("apiKeySet", settingsService.get(orgId, "whatsapp.api_key", "").isBlank() ? "false" : "true");
        return ResponseEntity.ok(result);
    }

    @PutMapping("/whatsapp")
    @PreAuthorize("hasRole('OWNER') or hasRole('ADMIN')")
    public ResponseEntity<Map<String, String>> updateWhatsAppSettings(@RequestBody Map<String, String> body) {
        UUID orgId = TenantContext.getCurrentOrgId();
        setIf(orgId, body, "enabled", "whatsapp.enabled");
        setIf(orgId, body, "provider", "whatsapp.provider");
        setIf(orgId, body, "phoneNumberId", "whatsapp.phone_number_id");
        setIf(orgId, body, "customUrl", "whatsapp.custom_url");
        setIf(orgId, body, "lang", "whatsapp.lang");
        setIf(orgId, body, "autoSendReceipt", "whatsapp.auto_send_receipt");
        setIf(orgId, body, "templateInvoice", "whatsapp.template_invoice");
        setIf(orgId, body, "templateReceipt", "whatsapp.template_receipt");
        setIf(orgId, body, "templateReminder", "whatsapp.template_reminder");
        setIf(orgId, body, "templateStatement", "whatsapp.template_statement");
        // Only overwrite the token when a non-blank value is supplied.
        if (body.get("apiKey") != null && !body.get("apiKey").isBlank()) {
            settingsService.set(orgId, "whatsapp.api_key", body.get("apiKey").trim());
        }
        return ResponseEntity.ok(getWhatsAppSettings().getBody());
    }

    private void setIf(UUID orgId, Map<String, String> body, String field, String key) {
        if (body.containsKey(field)) settingsService.set(orgId, key, body.get(field));
    }
}
