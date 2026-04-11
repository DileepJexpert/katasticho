package com.katasticho.erp.ar.controller;

import com.katasticho.erp.ar.dto.PaymentResponse;
import com.katasticho.erp.ar.dto.RecordPaymentRequest;
import com.katasticho.erp.ar.entity.Payment;
import com.katasticho.erp.ar.service.PaymentService;
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

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/payments")
@RequiredArgsConstructor
public class PaymentController {

    private final PaymentService paymentService;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<PaymentResponse>> recordPayment(@Valid @RequestBody RecordPaymentRequest request) {
        Payment payment = paymentService.recordPayment(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(paymentService.toResponse(payment)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<PaymentResponse>> getPayment(@PathVariable UUID id) {
        Payment payment = paymentService.getPayment(id);
        return ResponseEntity.ok(ApiResponse.ok(paymentService.toResponse(payment)));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<PaymentResponse>>> listPayments(Pageable pageable) {
        Page<Payment> page = paymentService.listPayments(pageable);
        Page<PaymentResponse> responsePage = page.map(paymentService::toResponse);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(responsePage)));
    }

    @GetMapping("/invoice/{invoiceId}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<PaymentResponse>>> getPaymentsForInvoice(@PathVariable UUID invoiceId) {
        List<PaymentResponse> payments = paymentService.getPaymentsForInvoice(invoiceId).stream()
                .map(paymentService::toResponse)
                .toList();
        return ResponseEntity.ok(ApiResponse.ok(payments));
    }
}
