package com.katasticho.erp.ap.controller;

import com.katasticho.erp.ap.dto.VendorPaymentRequest;
import com.katasticho.erp.ap.dto.VendorPaymentResponse;
import com.katasticho.erp.ap.service.VendorPaymentService;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.dto.EntityCommentResponse;
import com.katasticho.erp.common.dto.PagedResponse;
import com.katasticho.erp.common.service.CommentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/vendor-payments")
@RequiredArgsConstructor
public class VendorPaymentController {

    private final VendorPaymentService paymentService;
    private final CommentService commentService;
    private final com.katasticho.erp.ap.service.BulkPaymentExportService bulkPaymentExportService;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<VendorPaymentResponse>> recordPayment(
            @Valid @RequestBody VendorPaymentRequest request) {
        VendorPaymentResponse response = paymentService.recordPayment(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(response));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<VendorPaymentResponse>>> listPayments(
            @RequestParam(required = false) UUID contact_id,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date_from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date_to,
            Pageable pageable) {
        Page<VendorPaymentResponse> page = paymentService.listPaymentsFiltered(
                contact_id, date_from, date_to, pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<VendorPaymentResponse>> getPayment(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(paymentService.getPaymentResponse(id)));
    }

    @GetMapping("/{id}/cheque-print")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<com.katasticho.erp.ap.dto.ChequePrintResponse>> getChequePrint(
            @PathVariable UUID id,
            @RequestParam(required = false) String chequeNumber) {
        return ResponseEntity.ok(ApiResponse.ok(bulkPaymentExportService.getChequePrintData(id, chequeNumber)));
    }

    @PostMapping(value = "/bulk-export", produces = "text/csv")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<byte[]> exportBulkPaymentCsv(
            @Valid @RequestBody com.katasticho.erp.ap.dto.BulkPaymentExportRequest request) {
        byte[] csvBytes = bulkPaymentExportService.exportBulkPaymentCsv(request);
        String filename = bulkPaymentExportService.filename(request.format());
        return ResponseEntity.ok()
                .contentType(org.springframework.http.MediaType.parseMediaType("text/csv"))
                .header(org.springframework.http.HttpHeaders.CONTENT_DISPOSITION,
                        "attachment; filename=\"" + filename + "\"")
                .body(csvBytes);
    }

    @PostMapping("/{id}/void")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<VendorPaymentResponse>> voidPayment(
            @PathVariable UUID id) {
        VendorPaymentResponse response = paymentService.voidPayment(id);
        return ResponseEntity.ok(ApiResponse.ok(response, "Payment voided — journal reversed"));
    }

    @PostMapping("/{id}/comments")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<EntityCommentResponse>> addComment(
            @PathVariable UUID id,
            @RequestBody Map<String, String> body) {
        String text = body.getOrDefault("text", "");
        EntityCommentResponse comment = commentService.addComment("VENDOR_PAYMENT", id, text);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(comment));
    }

    @GetMapping("/{id}/comments")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<EntityCommentResponse>>> listComments(
            @PathVariable UUID id, Pageable pageable) {
        Page<EntityCommentResponse> page = commentService.listComments("VENDOR_PAYMENT", id, pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
    }
}
