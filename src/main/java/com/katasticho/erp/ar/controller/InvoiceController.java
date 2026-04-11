package com.katasticho.erp.ar.controller;

import com.katasticho.erp.ar.dto.CreateInvoiceRequest;
import com.katasticho.erp.ar.dto.InvoiceResponse;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.service.InvoiceService;
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

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/invoices")
@RequiredArgsConstructor
public class InvoiceController {

    private final InvoiceService invoiceService;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<InvoiceResponse>> createInvoice(@Valid @RequestBody CreateInvoiceRequest request) {
        Invoice invoice = invoiceService.createInvoice(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(invoiceService.toResponse(invoice)));
    }

    @PostMapping("/{id}/send")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<InvoiceResponse>> sendInvoice(@PathVariable UUID id) {
        Invoice invoice = invoiceService.sendInvoice(id);
        return ResponseEntity.ok(ApiResponse.ok(invoiceService.toResponse(invoice), "Invoice sent and journal posted"));
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<InvoiceResponse>> cancelInvoice(
            @PathVariable UUID id, @RequestBody Map<String, String> body) {
        String reason = body.getOrDefault("reason", "Cancelled");
        Invoice invoice = invoiceService.cancelInvoice(id, reason);
        return ResponseEntity.ok(ApiResponse.ok(invoiceService.toResponse(invoice), "Invoice cancelled"));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<InvoiceResponse>> getInvoice(@PathVariable UUID id) {
        Invoice invoice = invoiceService.getInvoice(id);
        return ResponseEntity.ok(ApiResponse.ok(invoiceService.toResponse(invoice)));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<InvoiceResponse>>> listInvoices(Pageable pageable) {
        Page<Invoice> page = invoiceService.listInvoices(pageable);
        Page<InvoiceResponse> responsePage = page.map(invoiceService::toResponse);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(responsePage)));
    }

    @GetMapping("/customer/{customerId}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<InvoiceResponse>>> listByCustomer(
            @PathVariable UUID customerId, Pageable pageable) {
        Page<Invoice> page = invoiceService.listInvoicesByCustomer(customerId, pageable);
        Page<InvoiceResponse> responsePage = page.map(invoiceService::toResponse);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(responsePage)));
    }
}
