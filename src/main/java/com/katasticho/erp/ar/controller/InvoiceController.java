package com.katasticho.erp.ar.controller;

import com.katasticho.erp.ar.dto.CreateInvoiceRequest;
import com.katasticho.erp.ar.dto.InvoiceResponse;
import com.katasticho.erp.ar.dto.PaymentResponse;
import com.katasticho.erp.ar.dto.RecordPaymentForInvoiceRequest;
import com.katasticho.erp.ar.service.InvoicePdfService;
import com.katasticho.erp.ar.service.InvoiceService;
import com.katasticho.erp.ar.service.PaymentService;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.dto.BulkIdsRequest;
import com.katasticho.erp.common.dto.BulkOperationResult;
import com.katasticho.erp.common.dto.PagedResponse;
import com.katasticho.erp.common.service.DocumentShareService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/invoices")
@RequiredArgsConstructor
public class InvoiceController {

    private final InvoiceService invoiceService;
    private final PaymentService paymentService;
    private final DocumentShareService documentShareService;
    private final InvoicePdfService invoicePdfService;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<InvoiceResponse>> createInvoice(@Valid @RequestBody CreateInvoiceRequest request) {
        InvoiceResponse response = invoiceService.createInvoice(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(response));
    }

    @PostMapping("/{id}/send")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<InvoiceResponse>> sendInvoice(@PathVariable UUID id) {
        InvoiceResponse response = invoiceService.sendInvoice(id);
        return ResponseEntity.ok(ApiResponse.ok(response, "Invoice sent and journal posted"));
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<InvoiceResponse>> cancelInvoice(
            @PathVariable UUID id, @RequestBody Map<String, String> body) {
        String reason = body.getOrDefault("reason", "Cancelled");
        InvoiceResponse response = invoiceService.cancelInvoice(id, reason);
        return ResponseEntity.ok(ApiResponse.ok(response, "Invoice cancelled"));
    }

    @PostMapping("/{invoiceId}/payments")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<PaymentResponse>> recordPaymentForInvoice(
            @PathVariable UUID invoiceId,
            @Valid @RequestBody RecordPaymentForInvoiceRequest request) {
        PaymentResponse response = paymentService.recordForInvoice(invoiceId, request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(response));
    }

    @GetMapping("/{invoiceId}/payments")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<PaymentResponse>>> listPaymentsForInvoice(
            @PathVariable UUID invoiceId) {
        List<PaymentResponse> payments = paymentService.listForInvoice(invoiceId);
        return ResponseEntity.ok(ApiResponse.ok(payments));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<InvoiceResponse>> getInvoice(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(invoiceService.getInvoiceResponse(id)));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<InvoiceResponse>>> listInvoices(
            @RequestParam(required = false) String status,
            Pageable pageable) {
        Page<InvoiceResponse> page = invoiceService.listInvoiceResponses(status, pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
    }

    @GetMapping("/contact/{contactId}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<InvoiceResponse>>> listByContact(
            @PathVariable UUID contactId, Pageable pageable) {
        Page<InvoiceResponse> page = invoiceService.listInvoiceResponsesByContact(contactId, pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
    }

    @GetMapping("/{id}/pdf")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<byte[]> downloadPdf(@PathVariable UUID id) {
        InvoiceResponse inv = invoiceService.getInvoiceResponse(id);
        byte[] pdf = invoicePdfService.generatePdf(inv);
        String filename = "invoice-" + inv.invoiceNumber().replaceAll("[/\\\\:*?\"<>|]", "-") + ".pdf";
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_PDF)
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .body(pdf);
    }

    @PostMapping("/bulk-send")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<BulkOperationResult>> bulkSend(
            @Valid @RequestBody BulkIdsRequest request) {
        BulkOperationResult result = invoiceService.bulkSend(request.ids());
        String msg = result.successCount() + " sent, " + result.failCount() + " failed";
        return ResponseEntity.ok(ApiResponse.ok(result, msg));
    }

    @PostMapping("/bulk-cancel")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<BulkOperationResult>> bulkCancel(
            @Valid @RequestBody BulkIdsRequest request) {
        String reason = request.resolvedReason("Bulk cancelled");
        BulkOperationResult result = invoiceService.bulkCancel(request.ids(), reason);
        String msg = result.successCount() + " cancelled, " + result.failCount() + " failed";
        return ResponseEntity.ok(ApiResponse.ok(result, msg));
    }

    @GetMapping("/{id}/whatsapp-link")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<Map<String, String>>> whatsappLink(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(documentShareService.shareInvoice(id)));
    }

    @GetMapping("/{id}/whatsapp-reminder")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<Map<String, String>>> whatsappReminder(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(documentShareService.shareInvoiceReminder(id)));
    }
}
