package com.katasticho.erp.payment.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.payment.dto.PayoutDisbursementRequest;
import com.katasticho.erp.payment.dto.PayoutDisbursementResponse;
import com.katasticho.erp.payment.service.PayoutDisbursementService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/payouts")
@RequiredArgsConstructor
public class PayoutController {

    private final PayoutDisbursementService payoutService;

    @PostMapping("/disburse")
    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN', 'ACCOUNTANT')")
    public ResponseEntity<ApiResponse<PayoutDisbursementResponse>> disburse(
            @Valid @RequestBody PayoutDisbursementRequest request) {
        PayoutDisbursementResponse response = payoutService.disburse(request);
        return ResponseEntity.ok(ApiResponse.ok(response, "Payout disbursed successfully"));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN', 'ACCOUNTANT', 'VIEWER')")
    public ResponseEntity<ApiResponse<Page<PayoutDisbursementResponse>>> listPayouts(
            @PageableDefault(size = 20) Pageable pageable) {
        Page<PayoutDisbursementResponse> response = payoutService.listPayouts(pageable);
        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    @PostMapping("/{id}/reconcile-accounting")
    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN', 'ACCOUNTANT')")
    public ResponseEntity<ApiResponse<PayoutDisbursementResponse>> reconcileAccounting(
            @PathVariable java.util.UUID id,
            @RequestParam java.util.UUID paidThroughAccountId) {
        PayoutDisbursementResponse response = payoutService.reconcileAccounting(id, paidThroughAccountId);
        return ResponseEntity.ok(ApiResponse.ok(response, "Accounting successfully reconciled for payout"));
    }
}
