package com.katasticho.erp.ar.controller;

import com.katasticho.erp.ar.dto.CreateInvoiceRequest;
import com.katasticho.erp.ar.dto.InvoiceResponse;
import com.katasticho.erp.ar.dto.PaymentResponse;
import com.katasticho.erp.ar.dto.RecordPaymentRequest;
import com.katasticho.erp.ar.entity.Payment;
import com.katasticho.erp.ar.service.InvoiceService;
import com.katasticho.erp.ar.service.PaymentService;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.dto.PagedResponse;
import com.katasticho.erp.common.service.DocumentShareService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/invoices")
@RequiredArgsConstructor
public class InvoiceController {

    private final InvoiceService invoiceService;
    private final PaymentService paymentService;
    private final DocumentShareService documentShareService;

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

    @PostMapping("/{id}/payments")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<PaymentResponse>> recordPayment(
            @PathVariable UUID id,
            @Valid @RequestBody RecordPaymentRequest request) {
        RecordPaymentRequest enriched = new RecordPaymentRequest(
                id, request.contactId(), request.paymentDate(), request.amount(),
                request.paymentMethod(), request.referenceNumber(),
                request.bankAccount(), request.notes());
        Payment payment = paymentService.recordPayment(enriched);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(paymentService.toResponse(payment)));
    }

    @GetMapping("/{id}/payments")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<java.util.List<PaymentResponse>>> listPaymentsForInvoice(@PathVariable UUID id) {
        var payments = paymentService.getPaymentsForInvoice(id).stream()
                .map(paymentService::toResponse).toList();
        return ResponseEntity.ok(ApiResponse.ok(payments));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<InvoiceResponse>> getInvoice(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(invoiceService.getInvoiceResponse(id)));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<InvoiceResponse>>> listInvoices(Pageable pageable) {
        Page<InvoiceResponse> page = invoiceService.listInvoiceResponses(pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
    }

    @GetMapping("/contact/{contactId}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<InvoiceResponse>>> listByContact(
            @PathVariable UUID contactId, Pageable pageable) {
        Page<InvoiceResponse> page = invoiceService.listInvoiceResponsesByContact(contactId, pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
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
