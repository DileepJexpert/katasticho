package com.katasticho.erp.ap.controller;

import com.katasticho.erp.ap.dto.ApplyVendorCreditRequest;
import com.katasticho.erp.ap.dto.CreateVendorCreditRequest;
import com.katasticho.erp.ap.dto.VendorCreditResponse;
import com.katasticho.erp.ap.entity.VendorCredit;
import com.katasticho.erp.ap.service.VendorCreditService;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.dto.PagedResponse;
import com.katasticho.erp.common.entity.EntityComment;
import com.katasticho.erp.common.service.CommentService;
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
@RequestMapping("/api/v1/vendor-credits")
@RequiredArgsConstructor
public class VendorCreditController {

    private final VendorCreditService creditService;
    private final CommentService commentService;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<VendorCreditResponse>> createCredit(
            @Valid @RequestBody CreateVendorCreditRequest request) {
        VendorCredit credit = creditService.createCredit(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(creditService.toResponse(credit)));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<VendorCreditResponse>>> listCredits(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) UUID contact_id,
            Pageable pageable) {
        Page<VendorCredit> page = creditService.listCreditsFiltered(status, contact_id, pageable);
        Page<VendorCreditResponse> responsePage = page.map(creditService::toResponse);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(responsePage)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<VendorCreditResponse>> getCredit(@PathVariable UUID id) {
        VendorCredit credit = creditService.getCredit(id);
        return ResponseEntity.ok(ApiResponse.ok(creditService.toResponse(credit)));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> deleteCredit(@PathVariable UUID id) {
        creditService.deleteCredit(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Credit deleted"));
    }

    @PostMapping("/{id}/post")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<VendorCreditResponse>> postCredit(@PathVariable UUID id) {
        VendorCredit credit = creditService.postCredit(id);
        return ResponseEntity.ok(ApiResponse.ok(creditService.toResponse(credit),
                "Vendor credit posted — journal entry created"));
    }

    @PostMapping("/{id}/void")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<VendorCreditResponse>> voidCredit(
            @PathVariable UUID id,
            @RequestBody(required = false) Map<String, String> body) {
        String reason = body != null ? body.getOrDefault("reason", "Voided") : "Voided";
        VendorCredit credit = creditService.voidCredit(id, reason);
        return ResponseEntity.ok(ApiResponse.ok(creditService.toResponse(credit), "Credit voided"));
    }

    @PostMapping("/{id}/apply")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<VendorCreditResponse>> applyCredit(
            @PathVariable UUID id,
            @Valid @RequestBody ApplyVendorCreditRequest request) {
        creditService.applyToBill(id, request);
        VendorCredit credit = creditService.getCredit(id);
        return ResponseEntity.ok(ApiResponse.ok(creditService.toResponse(credit), "Credit applied to bill"));
    }

    @PostMapping("/{id}/comments")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<EntityComment>> addComment(
            @PathVariable UUID id,
            @RequestBody Map<String, String> body) {
        String text = body.getOrDefault("text", "");
        EntityComment comment = commentService.addComment("VENDOR_CREDIT", id, text);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(comment));
    }

    @GetMapping("/{id}/comments")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<EntityComment>>> listComments(
            @PathVariable UUID id, Pageable pageable) {
        Page<EntityComment> page = commentService.listComments("VENDOR_CREDIT", id, pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
    }
}
