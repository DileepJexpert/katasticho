package com.katasticho.erp.paymentterm.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.paymentterm.dto.PaymentTermDtos.PaymentTermRequest;
import com.katasticho.erp.paymentterm.dto.PaymentTermDtos.PaymentTermResponse;
import com.katasticho.erp.paymentterm.service.PaymentTermService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/** CRUD for payment terms (named instalment schedules). */
@RestController
@RequestMapping("/api/v1/payment-terms")
@RequiredArgsConstructor
public class PaymentTermController {

    private final PaymentTermService service;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<PaymentTermResponse>> create(@RequestBody PaymentTermRequest req) {
        return ResponseEntity.ok(ApiResponse.ok(service.create(req), "Payment term created"));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<PaymentTermResponse>> update(
            @PathVariable UUID id, @RequestBody PaymentTermRequest req) {
        return ResponseEntity.ok(ApiResponse.ok(service.update(id, req), "Payment term updated"));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {
        service.delete(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Payment term deleted"));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<PaymentTermResponse>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.get(id)));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<List<PaymentTermResponse>>> list(
            @RequestParam(name = "activeOnly", defaultValue = "false") boolean activeOnly) {
        return ResponseEntity.ok(ApiResponse.ok(service.list(activeOnly)));
    }
}
