package com.katasticho.erp.notification.whatsapp;

import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/**
 * Send business documents over WhatsApp (template + PDF) and view the send log.
 * Distinct from the existing wa.me "share link" endpoints — these go through the
 * WhatsApp Business API for proper delivery with an attached document.
 */
@RestController
@RequestMapping("/api/v1/whatsapp")
@RequiredArgsConstructor
public class WhatsAppController {

    private final WhatsAppDocumentService documentService;

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
}
