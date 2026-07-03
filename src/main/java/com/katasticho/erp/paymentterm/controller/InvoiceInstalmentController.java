package com.katasticho.erp.paymentterm.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.paymentterm.dto.PaymentTermDtos.InstalmentScheduleResponse;
import com.katasticho.erp.paymentterm.service.PaymentTermService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/** Apply / read / clear an invoice's instalment schedule. */
@RestController
@RequestMapping("/api/v1/invoices/{invoiceId}/instalments")
@RequiredArgsConstructor
public class InvoiceInstalmentController {

    private final PaymentTermService service;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<InstalmentScheduleResponse>> apply(
            @PathVariable UUID invoiceId, @RequestParam UUID paymentTermId) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.applyToInvoice(invoiceId, paymentTermId), "Instalment schedule applied"));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<InstalmentScheduleResponse>> get(@PathVariable UUID invoiceId) {
        return ResponseEntity.ok(ApiResponse.ok(service.getSchedule(invoiceId)));
    }

    @DeleteMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> clear(@PathVariable UUID invoiceId) {
        service.clearInstalments(invoiceId);
        return ResponseEntity.ok(ApiResponse.ok(null, "Instalment schedule cleared"));
    }
}
