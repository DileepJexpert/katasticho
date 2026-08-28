package com.katasticho.erp.pos.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.dto.PagedResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.pos.dto.BatchOfflineSyncResponse;
import com.katasticho.erp.pos.dto.CreateSalesReceiptRequest;
import com.katasticho.erp.pos.dto.CustomerHistoryResponse;
import com.katasticho.erp.pos.dto.SalesReceiptResponse;
import com.katasticho.erp.pos.service.ReceiptPdfService;
import com.katasticho.erp.pos.service.ReceiptShareService;
import com.katasticho.erp.pos.service.SalesReceiptService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/sales-receipts")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.POS)
public class SalesReceiptController {

    private final SalesReceiptService salesReceiptService;
    private final ReceiptPdfService receiptPdfService;
    private final ReceiptShareService receiptShareService;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<SalesReceiptResponse>> create(
            @Valid @RequestBody CreateSalesReceiptRequest request) {
        SalesReceiptResponse response = salesReceiptService.create(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(response));
    }

    @PostMapping("/offline-sync")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<BatchOfflineSyncResponse>> offlineSync(
            @RequestBody List<@Valid CreateSalesReceiptRequest> requests) {
        BatchOfflineSyncResponse response = salesReceiptService.batchOfflineSync(requests);
        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<SalesReceiptResponse>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(salesReceiptService.getById(id)));
    }

    /**
     * Return / void a completed POS sale — reverses the journal + restocks.
     * OWNER/ADMIN/ACCOUNTANT only (a cash-sale reversal is sensitive; OPERATOR
     * is intentionally excluded). Body: optional {@code {"reason": "..."}}.
     */
    @PostMapping("/{id}/return")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<SalesReceiptResponse>> returnReceipt(
            @PathVariable UUID id,
            @RequestBody(required = false) Map<String, String> body) {
        String reason = body != null ? body.get("reason") : null;
        return ResponseEntity.ok(ApiResponse.ok(salesReceiptService.voidReceipt(id, reason)));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<SalesReceiptResponse>>> list(
            @RequestParam(required = false) UUID branchId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateFrom,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateTo,
            @RequestParam(required = false) String paymentMode,
            Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(
                salesReceiptService.list(branchId, dateFrom, dateTo, paymentMode, pageable)));
    }

    @GetMapping("/{id}/print")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<byte[]> printReceipt(@PathVariable UUID id) {
        byte[] pdf = receiptPdfService.generateReceiptPdf(id);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        "attachment; filename=receipt-" + id + ".pdf")
                .contentType(MediaType.APPLICATION_PDF)
                .contentLength(pdf.length)
                .body(pdf);
    }

    @PostMapping("/{id}/whatsapp-link")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<Map<String, String>>> whatsappLink(@PathVariable UUID id) {
        Map<String, String> linkData = receiptShareService.generateShareLink(id);
        return ResponseEntity.ok(ApiResponse.ok(linkData));
    }

    @GetMapping("/customer/{contactId}/history")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<CustomerHistoryResponse>> customerHistory(
            @PathVariable UUID contactId,
            @RequestParam(required = false, defaultValue = "180") int days) {
        return ResponseEntity.ok(ApiResponse.ok(
                salesReceiptService.getCustomerHistory(contactId, days)));
    }
}
