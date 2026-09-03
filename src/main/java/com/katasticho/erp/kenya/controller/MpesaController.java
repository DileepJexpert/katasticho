package com.katasticho.erp.kenya.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.kenya.dto.MpesaStkPushRequest;
import com.katasticho.erp.kenya.dto.MpesaTransactionResponse;
import com.katasticho.erp.kenya.service.MpesaService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/kenya/mpesa")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER', 'ADMIN', 'ACCOUNTANT', 'OPERATOR')")
public class MpesaController {

    private final MpesaService service;

    @GetMapping("/transactions")
    public ApiResponse<List<MpesaTransactionResponse>> listTransactions(
            @RequestParam(required = false) String status) {
        return ApiResponse.ok(service.listTransactions(status));
    }

    @PostMapping("/stk-push")
    public ApiResponse<MpesaTransactionResponse> initiateStkPush(
            @Valid @RequestBody MpesaStkPushRequest request) {
        return ApiResponse.ok(service.initiateStkPush(request));
    }

    @PostMapping("/transactions/{id}/reconcile")
    public ApiResponse<MpesaTransactionResponse> reconcile(
            @PathVariable UUID id,
            @RequestParam UUID invoiceId) {
        return ApiResponse.ok(service.reconcileWithInvoice(id, invoiceId));
    }
}