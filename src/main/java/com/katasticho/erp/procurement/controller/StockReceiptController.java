package com.katasticho.erp.procurement.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.dto.PagedResponse;
import com.katasticho.erp.procurement.dto.CreateStockReceiptRequest;
import com.katasticho.erp.procurement.dto.StockReceiptResponse;
import com.katasticho.erp.procurement.service.StockReceiptService;
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
@RequestMapping("/api/v1/stock-receipts")
@RequiredArgsConstructor
public class StockReceiptController {

    private final StockReceiptService stockReceiptService;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<StockReceiptResponse>> createReceipt(
            @Valid @RequestBody CreateStockReceiptRequest request) {
        StockReceiptResponse response = stockReceiptService.createDraft(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(response));
    }

    @PostMapping("/{id}/receive")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<StockReceiptResponse>> receiveReceipt(@PathVariable UUID id) {
        StockReceiptResponse response = stockReceiptService.receive(id);
        return ResponseEntity.ok(ApiResponse.ok(response, "Stock received and ledger updated"));
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<StockReceiptResponse>> cancelReceipt(
            @PathVariable UUID id, @RequestBody Map<String, String> body) {
        String reason = body.getOrDefault("reason", "Cancelled");
        StockReceiptResponse response = stockReceiptService.cancel(id, reason);
        return ResponseEntity.ok(ApiResponse.ok(response, "Stock receipt cancelled"));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<StockReceiptResponse>> getReceipt(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(stockReceiptService.getReceipt(id)));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<StockReceiptResponse>>> listReceipts(
            @RequestParam(required = false) UUID supplierId,
            Pageable pageable) {
        Page<StockReceiptResponse> page = stockReceiptService.listReceipts(supplierId, pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
    }
}
