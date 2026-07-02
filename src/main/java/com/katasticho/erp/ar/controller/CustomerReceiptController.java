package com.katasticho.erp.ar.controller;

import com.katasticho.erp.ar.dto.CustomerReceiptRequest;
import com.katasticho.erp.ar.dto.CustomerReceiptResponse;
import com.katasticho.erp.ar.service.CustomerReceiptService;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.dto.PagedResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Customer receipts: one lump-sum collection allocated across many invoices,
 * with any excess parked as a customer advance. Distinct from the legacy
 * single-invoice {@code /api/v1/payments} endpoint.
 */
@RestController
@RequestMapping("/api/v1/customer-receipts")
@RequiredArgsConstructor
public class CustomerReceiptController {

    private final CustomerReceiptService receiptService;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<CustomerReceiptResponse>> recordReceipt(
            @Valid @RequestBody CustomerReceiptRequest request) {
        CustomerReceiptResponse response = receiptService.recordReceipt(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(response));
    }

    /**
     * Khata settlement — collect against a customer's invoice-less outstanding
     * (POS credit sales). OPERATOR allowed: this happens at the counter.
     * Body: {contactId, amount, paymentMethod?, receiptDate?, notes?}.
     */
    @PostMapping("/khata-settlement")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<CustomerReceiptResponse>> recordKhataSettlement(
            @RequestBody Map<String, String> body) {
        UUID contactId = UUID.fromString(body.get("contactId"));
        BigDecimal amount = new BigDecimal(body.get("amount"));
        String paymentMethod = body.getOrDefault("paymentMethod", "CASH");
        java.time.LocalDate receiptDate = body.get("receiptDate") != null
                ? java.time.LocalDate.parse(body.get("receiptDate"))
                : java.time.LocalDate.now();
        CustomerReceiptResponse response = receiptService.recordKhataSettlement(
                contactId, amount, paymentMethod, receiptDate, body.get("notes"));
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(response));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<CustomerReceiptResponse>>> listReceipts(
            @RequestParam(required = false) UUID contact_id,
            Pageable pageable) {
        Page<CustomerReceiptResponse> page = contact_id != null
                ? receiptService.listReceiptsByContact(contact_id, pageable)
                : receiptService.listReceipts(pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<CustomerReceiptResponse>> getReceipt(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(receiptService.getReceiptResponse(id)));
    }

    @PostMapping("/{id}/void")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<CustomerReceiptResponse>> voidReceipt(
            @PathVariable UUID id,
            @RequestBody(required = false) Map<String, String> body) {
        String reason = body != null ? body.getOrDefault("reason", "Voided") : "Voided";
        CustomerReceiptResponse response = receiptService.voidReceipt(id, reason);
        return ResponseEntity.ok(ApiResponse.ok(response, "Receipt voided — journal reversed"));
    }

    @GetMapping("/invoice/{invoiceId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<CustomerReceiptResponse>>> listForInvoice(@PathVariable UUID invoiceId) {
        return ResponseEntity.ok(ApiResponse.ok(receiptService.listReceiptsForInvoice(invoiceId)));
    }

    @GetMapping("/advance/{contactId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<Map<String, BigDecimal>>> availableAdvance(@PathVariable UUID contactId) {
        return ResponseEntity.ok(ApiResponse.ok(
                Map.of("availableAdvance", receiptService.availableAdvance(contactId))));
    }
}
