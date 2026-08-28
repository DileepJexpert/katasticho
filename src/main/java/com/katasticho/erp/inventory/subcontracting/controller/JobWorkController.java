package com.katasticho.erp.inventory.subcontracting.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.inventory.subcontracting.service.JobWorkService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/inventory/job-work")
@RequiredArgsConstructor
public class JobWorkController {

    private final JobWorkService jobWorkService;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<Page<JobWorkService.JobWorkOrderResponse>>> listOrders(
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(jobWorkService.listOrders(pageable)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<JobWorkService.JobWorkOrderResponse>> getOrder(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(jobWorkService.getOrder(id)));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<JobWorkService.JobWorkOrderResponse>> createOrder(
            @RequestBody JobWorkService.CreateJobWorkOrderRequest req) {
        return ResponseEntity.ok(ApiResponse.ok(jobWorkService.createOrder(req), "Job Work Order created"));
    }

    @PostMapping("/{id}/receipts")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<JobWorkService.JobWorkOrderResponse>> recordReceipt(
            @PathVariable UUID id,
            @RequestBody JobWorkService.ReceiveJobWorkRequest req) {
        return ResponseEntity.ok(ApiResponse.ok(jobWorkService.recordReceipt(id, req), "Inward goods receipt recorded"));
    }

    @GetMapping("/itc-04")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<JobWorkService.Itc04SummaryResponse>> getItc04Report(
            @RequestParam(defaultValue = "Q1") String quarter,
            @RequestParam(defaultValue = "2026") int year) {
        return ResponseEntity.ok(ApiResponse.ok(jobWorkService.getItc04Summary(quarter, year)));
    }
}
