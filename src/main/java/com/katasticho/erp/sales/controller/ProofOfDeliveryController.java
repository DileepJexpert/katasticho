package com.katasticho.erp.sales.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.entity.EntityAttachment;
import com.katasticho.erp.sales.entity.ProofOfDelivery;
import com.katasticho.erp.sales.service.ProofOfDeliveryService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.UUID;

/**
 * Proof of Delivery endpoints. OPERATOR can record + read (delivery boys
 * on the field), OWNER/ADMIN/ACCOUNTANT additionally can delete.
 */
@RestController
@RequestMapping("/api/v1/proof-of-delivery")
@RequiredArgsConstructor
public class ProofOfDeliveryController {

    private final ProofOfDeliveryService service;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<ProofOfDelivery>> record(@RequestBody ProofOfDelivery body) {
        return ResponseEntity.ok(ApiResponse.ok(service.record(body), "Proof of delivery recorded"));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<ProofOfDelivery>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.get(id)));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<ProofOfDelivery>>> list(
            @RequestParam(required = false) UUID challanId,
            @RequestParam(required = false) UUID invoiceId,
            @RequestParam(required = false) UUID contactId) {
        List<ProofOfDelivery> rows;
        if (challanId != null) {
            rows = service.listByChallan(challanId);
        } else if (invoiceId != null) {
            rows = service.listByInvoice(invoiceId);
        } else if (contactId != null) {
            rows = service.listByContact(contactId);
        } else {
            rows = service.recent();
        }
        return ResponseEntity.ok(ApiResponse.ok(rows));
    }

    @PostMapping(value = "/{id}/attachments", consumes = "multipart/form-data")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<EntityAttachment>> attachFile(
            @PathVariable UUID id, @RequestParam("file") MultipartFile file) {
        return ResponseEntity.ok(ApiResponse.ok(service.attachFile(id, file), "Attached"));
    }

    @GetMapping("/{id}/attachments")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<EntityAttachment>>> listAttachments(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.listAttachments(id)));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {
        service.delete(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Removed"));
    }
}
