package com.katasticho.erp.ai.controller;

import com.katasticho.erp.ai.dto.AiQueryRequest;
import com.katasticho.erp.ai.dto.AiQueryResponse;
import com.katasticho.erp.ai.dto.BillScanRequest;
import com.katasticho.erp.ai.dto.BillScanResponse;
import com.katasticho.erp.ai.service.BillScanService;
import com.katasticho.erp.ai.service.NlpQueryService;
import com.katasticho.erp.common.dto.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/ai")
@RequiredArgsConstructor
public class AiController {

    private final NlpQueryService nlpQueryService;
    private final BillScanService billScanService;

    /**
     * POST /api/v1/ai/query
     * Natural language query → SQL → results → human-readable answer.
     * Read-only. Uses Claude to generate safe SELECT queries.
     */
    @PostMapping("/query")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<AiQueryResponse>> query(
            @Valid @RequestBody AiQueryRequest request) {
        AiQueryResponse response = nlpQueryService.processQuery(request.message());
        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    /**
     * POST /api/v1/ai/scan-bill
     * Upload a bill image (base64) → Claude Vision extracts structured data.
     * Returns vendor, items, GST breakdown for pre-filling invoice forms.
     */
    @PostMapping("/scan-bill")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<BillScanResponse>> scanBill(
            @Valid @RequestBody BillScanRequest request) {
        BillScanResponse response = billScanService.scanBill(
                request.image(), request.effectiveMediaType());
        return ResponseEntity.ok(ApiResponse.ok(response));
    }
}
