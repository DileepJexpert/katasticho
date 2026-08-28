package com.katasticho.erp.notification.whatsapp;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.organisation.OrgSettingsService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Send business documents over WhatsApp (template + PDF), test automated bot conversations,
 * view audit message logs, and manage bot webhook credentials.
 */
@RestController
@RequestMapping("/api/v1/whatsapp")
@RequiredArgsConstructor
public class WhatsAppController {

    private final WhatsAppDocumentService documentService;
    private final WhatsAppBotService botService;
    private final WhatsAppService whatsAppService;
    private final OrgSettingsService orgSettingsService;

    @PostMapping("/invoices/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<WhatsAppMessage>> sendInvoice(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(documentService.sendInvoice(id), "WhatsApp send attempted"));
    }

    @PostMapping("/receipts/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<WhatsAppMessage>> sendReceipt(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(documentService.sendReceipt(id), "WhatsApp send attempted"));
    }

    @PostMapping("/reminders/{contactId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<WhatsAppMessage>> sendReminder(@PathVariable UUID contactId) {
        return ResponseEntity.ok(ApiResponse.ok(documentService.sendReminder(contactId), "WhatsApp send attempted"));
    }

    @PostMapping("/statements/{contactId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<WhatsAppMessage>> sendStatement(@PathVariable UUID contactId) {
        return ResponseEntity.ok(ApiResponse.ok(documentService.sendStatement(contactId), "WhatsApp send attempted"));
    }

    @GetMapping("/messages")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<WhatsAppMessage>>> messages() {
        return ResponseEntity.ok(ApiResponse.ok(documentService.recent()));
    }

    /**
     * Interactive Bot Simulator Endpoint: lets owners test sending commands (MENU, BALANCE, ORDER, etc.)
     * and see instant bot responses.
     */
    @PostMapping("/simulate-bot")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<WhatsAppBotService.BotReply>> simulateBot(
            @RequestBody BotSimulationRequest req) {
        UUID orgId = TenantContext.getCurrentOrgId();
        WhatsAppBotService.BotReply reply = botService.simulate(orgId, req.contactId(), req.message(), req.fromPhone());
        return ResponseEntity.ok(ApiResponse.ok(reply, "Bot response generated"));
    }

    @GetMapping("/settings")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getSettings() {
        UUID orgId = TenantContext.getCurrentOrgId();
        Map<String, Object> settings = new HashMap<>(whatsAppService.settings(orgId));
        String token = botService.ensureWebhookToken(orgId);
        settings.put("webhookToken", token);
        settings.put("webhookUrl", "/api/v1/whatsapp/webhook/" + token);
        settings.put("verifyToken", token);
        return ResponseEntity.ok(ApiResponse.ok(settings));
    }

    @PutMapping("/settings")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> updateSettings(@RequestBody Map<String, String> body) {
        UUID orgId = TenantContext.getCurrentOrgId();
        body.forEach((key, val) -> {
            if (val != null) {
                orgSettingsService.set(orgId, key, val);
            }
        });
        return getSettings();
    }

    public record BotSimulationRequest(UUID contactId, String message, String fromPhone) {}
}
