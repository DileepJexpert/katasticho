package com.katasticho.erp.inventory.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.inventory.entity.BatchTrace;
import com.katasticho.erp.inventory.service.BatchTraceService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/inventory/batch-trace")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR','ACCOUNTANT')")
public class BatchTraceController {

    private final BatchTraceService service;

    @GetMapping("/forward/{batchId}")
    public ResponseEntity<ApiResponse<List<BatchTrace>>> traceForward(@PathVariable UUID batchId) {
        return ResponseEntity.ok(ApiResponse.ok(service.traceForward(batchId)));
    }

    @GetMapping("/backward/{batchId}")
    public ResponseEntity<ApiResponse<List<BatchTrace>>> traceBackward(@PathVariable UUID batchId) {
        return ResponseEntity.ok(ApiResponse.ok(service.traceBackward(batchId)));
    }

    @GetMapping("/history/{batchId}")
    public ResponseEntity<ApiResponse<Map<String, List<BatchTrace>>>> getTraceHistory(
            @PathVariable UUID batchId) {
        return ResponseEntity.ok(ApiResponse.ok(service.getTraceHistory(batchId)));
    }

    /**
     * Batch recall report — given a (potentially defective) raw-material
     * batch id, returns every finished-goods batch it was mixed into and
     * every downstream sales movement of those FG batches with the
     * customer name + invoice number. Sorted most-recent shipment first
     * so the recall team can phone today's customers before yesterday's.
     */
    @GetMapping("/recall/{rmBatchId}")
    public ResponseEntity<ApiResponse<Map<String, Object>>> recall(@PathVariable UUID rmBatchId) {
        return ResponseEntity.ok(ApiResponse.ok(service.recallReport(rmBatchId)));
    }
}
