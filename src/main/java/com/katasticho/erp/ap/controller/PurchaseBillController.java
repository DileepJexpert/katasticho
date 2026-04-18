package com.katasticho.erp.ap.controller;

import com.katasticho.erp.ap.dto.CreatePurchaseBillRequest;
import com.katasticho.erp.ap.dto.PurchaseBillResponse;
import com.katasticho.erp.ap.dto.UpdatePurchaseBillRequest;
import com.katasticho.erp.ap.dto.VendorPaymentResponse;
import com.katasticho.erp.ap.service.PurchaseBillService;
import com.katasticho.erp.ap.service.VendorPaymentService;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.dto.BulkIdsRequest;
import com.katasticho.erp.common.dto.BulkOperationResult;
import com.katasticho.erp.common.dto.EntityCommentResponse;
import com.katasticho.erp.common.dto.PagedResponse;
import com.katasticho.erp.common.entity.EntityAttachment;
import com.katasticho.erp.common.service.AttachmentService;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.common.service.DocumentShareService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/bills")
@RequiredArgsConstructor
public class PurchaseBillController {

    private final PurchaseBillService billService;
    private final VendorPaymentService paymentService;
    private final CommentService commentService;
    private final AttachmentService attachmentService;
    private final DocumentShareService documentShareService;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<PurchaseBillResponse>> createBill(
            @Valid @RequestBody CreatePurchaseBillRequest request) {
        PurchaseBillResponse response = billService.createBill(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(response));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<PurchaseBillResponse>>> listBills(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) UUID contact_id,
            @RequestParam(required = false) UUID branch_id,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date_from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date_to,
            Pageable pageable) {
        Page<PurchaseBillResponse> page = billService.listBillsFiltered(
                status, contact_id, branch_id, date_from, date_to, pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<PurchaseBillResponse>> getBill(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(billService.getBillResponse(id)));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<PurchaseBillResponse>> updateBill(
            @PathVariable UUID id,
            @Valid @RequestBody UpdatePurchaseBillRequest request) {
        PurchaseBillResponse response = billService.updateBill(id, request);
        return ResponseEntity.ok(ApiResponse.ok(response, "Bill updated"));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> deleteBill(@PathVariable UUID id) {
        billService.deleteBill(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Bill deleted"));
    }

    @PostMapping("/{id}/post")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<PurchaseBillResponse>> postBill(@PathVariable UUID id) {
        PurchaseBillResponse response = billService.postBill(id);
        return ResponseEntity.ok(ApiResponse.ok(response, "Bill posted — journal entry created"));
    }

    @PostMapping("/{id}/void")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<PurchaseBillResponse>> voidBill(
            @PathVariable UUID id,
            @RequestBody(required = false) Map<String, String> body) {
        String reason = body != null ? body.getOrDefault("reason", "Voided") : "Voided";
        PurchaseBillResponse response = billService.voidBill(id, reason);
        return ResponseEntity.ok(ApiResponse.ok(response, "Bill voided"));
    }

    @GetMapping("/{id}/payments")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<VendorPaymentResponse>>> getBillPayments(
            @PathVariable UUID id) {
        List<VendorPaymentResponse> payments = paymentService.listPaymentsForBill(id);
        return ResponseEntity.ok(ApiResponse.ok(payments));
    }

    @PostMapping("/{id}/comments")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<EntityCommentResponse>> addComment(
            @PathVariable UUID id,
            @RequestBody Map<String, String> body) {
        String text = body.getOrDefault("text", "");
        EntityCommentResponse comment = commentService.addComment("BILL", id, text);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(comment));
    }

    @GetMapping("/{id}/comments")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<EntityCommentResponse>>> listComments(
            @PathVariable UUID id, Pageable pageable) {
        Page<EntityCommentResponse> page = commentService.listComments("BILL", id, pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
    }

    @PostMapping("/{id}/attachments")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<EntityAttachment>> uploadAttachment(
            @PathVariable UUID id,
            @RequestParam("file") MultipartFile file) {
        EntityAttachment attachment = attachmentService.upload("BILL", id, file);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(attachment));
    }

    @GetMapping("/{id}/attachments")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<EntityAttachment>>> listAttachments(@PathVariable UUID id) {
        List<EntityAttachment> attachments = attachmentService.list("BILL", id);
        return ResponseEntity.ok(ApiResponse.ok(attachments));
    }

    @PostMapping("/bulk-post")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<BulkOperationResult>> bulkPost(
            @Valid @RequestBody BulkIdsRequest request) {
        BulkOperationResult result = billService.bulkPost(request.ids());
        String msg = result.successCount() + " posted, " + result.failCount() + " failed";
        return ResponseEntity.ok(ApiResponse.ok(result, msg));
    }

    @PostMapping("/bulk-void")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<BulkOperationResult>> bulkVoid(
            @Valid @RequestBody BulkIdsRequest request) {
        String reason = request.resolvedReason("Bulk voided");
        BulkOperationResult result = billService.bulkVoid(request.ids(), reason);
        String msg = result.successCount() + " voided, " + result.failCount() + " failed";
        return ResponseEntity.ok(ApiResponse.ok(result, msg));
    }

    @GetMapping("/{id}/whatsapp-link")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Map<String, String>>> whatsappLink(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(documentShareService.shareBill(id)));
    }
}
