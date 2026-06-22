package com.katasticho.erp.gst.controller;

import com.katasticho.erp.common.country.RequiresCountry;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.gst.entity.EInvoice;
import com.katasticho.erp.gst.service.EInvoiceService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * e-Invoice (IRN) lifecycle: list pending/generated entries, download the IRP
 * INV-01 JSON, record the IRN obtained from the portal/GSP, cancel, and toggle
 * the org-level enablement.
 */
@RestController
@RequestMapping("/api/v1/gst/einvoices")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.GST)
@RequiresCountry("IN")
public class EInvoiceController {

    private final EInvoiceService eInvoiceService;
    private final ObjectMapper objectMapper;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<EInvoice>>> list(
            @RequestParam(required = false) String status) {
        return ResponseEntity.ok(ApiResponse.ok(eInvoiceService.list(status)));
    }

    /** Manually flag an invoice as needing an IRN (auto-detection covers posted B2B). */
    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<EInvoice>> create(@RequestBody Map<String, String> body) {
        UUID invoiceId = UUID.fromString(body.get("invoiceId"));
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(eInvoiceService.create(invoiceId)));
    }

    /** IRP INV-01 schema JSON, ready for the e-invoice portal / GSP upload. */
    @GetMapping("/{id}/portal-json")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<byte[]> portalJson(@PathVariable UUID id) throws Exception {
        Map<String, Object> data = eInvoiceService.portalJson(id);
        byte[] json = objectMapper.writerWithDefaultPrettyPrinter().writeValueAsBytes(data);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"einvoice.json\"")
                .contentType(MediaType.APPLICATION_JSON)
                .body(json);
    }

    /** One-click: generate the IRN directly via the configured GSP. */
    @PostMapping("/{id}/generate-gsp")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<EInvoice>> generateViaGsp(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                eInvoiceService.generateViaGsp(id), "IRN generated via GSP"));
    }

    /** Record the IRN + Ack + signed QR obtained from the IRP. */
    @PostMapping("/{id}/record")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<EInvoice>> record(
            @PathVariable UUID id,
            @RequestBody Map<String, String> body) {
        EInvoice updated = eInvoiceService.recordGenerated(
                id, body.get("irn"), body.get("ackNumber"), body.get("ackDate"), body.get("signedQr"));
        return ResponseEntity.ok(ApiResponse.ok(updated, "IRN recorded"));
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<EInvoice>> cancel(
            @PathVariable UUID id,
            @RequestBody(required = false) Map<String, String> body) {
        String reason = body != null ? body.get("reason") : null;
        return ResponseEntity.ok(ApiResponse.ok(
                eInvoiceService.cancel(id, reason), "e-Invoice entry cancelled"));
    }

    // ── Org-level enablement ─────────────────────────────────────────────

    @GetMapping("/settings")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> settings() {
        return ResponseEntity.ok(ApiResponse.ok(eInvoiceService.settings()));
    }

    @PutMapping("/settings")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> updateSettings(
            @RequestBody Map<String, Object> body) {
        eInvoiceService.setEnabled(Boolean.TRUE.equals(body.get("enabled"))
                || "true".equalsIgnoreCase(String.valueOf(body.get("enabled"))));
        return ResponseEntity.ok(ApiResponse.ok(eInvoiceService.settings(), "e-Invoice setting updated"));
    }
}
