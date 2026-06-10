package com.katasticho.erp.ai.controller;

import com.katasticho.erp.ai.dto.BillDraftFromScanRequest;
import com.katasticho.erp.ai.dto.BillDraftResult;
import com.katasticho.erp.ai.service.BillDraftingService;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

/**
 * AI-first purchase bill drafting — "draft, don't type".
 *
 * <p>A scanned (and optionally edited) bill is turned into a DRAFT purchase
 * bill the human reviews and approves in one tap, instead of filling a blank
 * form. Approval posts the bill through the normal AP path; rejection deletes
 * the draft. The AI only ever drafts — a human always approves.
 */
@RestController
@RequestMapping("/api/v1/ai/bill-drafts")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.AI_INBOX)
public class BillDraftingController {

    private final BillDraftingService billDraftingService;

    /** Draft a DRAFT purchase bill + AI Inbox suggestion from scanned data. */
    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<BillDraftResult>> draft(
            @Valid @RequestBody BillDraftFromScanRequest request) {
        BillDraftResult result = billDraftingService.draftFromScan(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(result));
    }

    /** Approve a drafted bill — posts it and records the learning signal. */
    @PostMapping("/{suggestionId}/approve")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<BillDraftResult>> approve(@PathVariable UUID suggestionId) {
        BillDraftResult result = billDraftingService.approve(suggestionId);
        return ResponseEntity.ok(ApiResponse.ok(result, "Bill posted — journal entry created"));
    }

    /** Reject a drafted bill — deletes the DRAFT. */
    @PostMapping("/{suggestionId}/reject")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> reject(
            @PathVariable UUID suggestionId,
            @RequestBody(required = false) Map<String, String> body) {
        String reason = body != null ? body.get("reason") : null;
        billDraftingService.reject(suggestionId, reason);
        return ResponseEntity.ok(ApiResponse.<Void>ok(null, "Drafted bill rejected"));
    }
}
