package com.katasticho.erp.expense.reimbursement.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.dto.PagedResponse;
import com.katasticho.erp.expense.reimbursement.dto.*;
import com.katasticho.erp.expense.reimbursement.service.EmployeeReimbursementService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/employee-reimbursements")
@RequiredArgsConstructor
public class EmployeeReimbursementController {
    private final EmployeeReimbursementService service;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<ReimbursementResponse>> submit(@Valid @RequestBody CreateReimbursementRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(service.submit(request)));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<ReimbursementResponse>>> list(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) UUID employeeId,
            Pageable pageable) {
        Page<ReimbursementResponse> page = service.list(status, employeeId, pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ApiResponse<ReimbursementResponse> get(@PathVariable UUID id) { return ApiResponse.ok(service.get(id)); }

    @PostMapping("/{id}/approve")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ApiResponse<ReimbursementResponse> approve(@PathVariable UUID id) { return ApiResponse.ok(service.approve(id), "Reimbursement approved"); }

    @PostMapping("/{id}/reject")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ApiResponse<ReimbursementResponse> reject(@PathVariable UUID id, @Valid @RequestBody RejectReimbursementRequest request) {
        return ApiResponse.ok(service.reject(id, request.reason()), "Reimbursement rejected");
    }

    @PostMapping("/{id}/pay")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ApiResponse<ReimbursementResponse> pay(@PathVariable UUID id, @Valid @RequestBody PayReimbursementRequest request) {
        return ApiResponse.ok(service.pay(id, request), "Reimbursement paid");
    }

    @PostMapping("/advances")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<EmployeeAdvanceResponse>> createAdvance(@Valid @RequestBody CreateEmployeeAdvanceRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(service.createAdvance(request)));
    }

    @GetMapping("/advances")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ApiResponse<PagedResponse<EmployeeAdvanceResponse>> listAdvances(Pageable pageable) {
        return ApiResponse.ok(PagedResponse.from(service.listAdvances(pageable)));
    }
}
