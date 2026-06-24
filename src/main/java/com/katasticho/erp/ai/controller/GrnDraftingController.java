package com.katasticho.erp.ai.controller;

import com.katasticho.erp.ai.dto.GrnDraftFromScanRequest;
import com.katasticho.erp.ai.dto.GrnDraftResult;
import com.katasticho.erp.ai.dto.GrnScanResponse;
import com.katasticho.erp.ai.service.GrnDraftingService;
import com.katasticho.erp.ai.service.GrnScanService;
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
 * AI-first goods-receipt drafting — "scan, don't type".
 *
 * <p>A scanned supplier invoice / challan is turned into a DRAFT
 * {@code stock_receipt} the operator reviews and approves in one tap. Approval
 * posts the receipt through the normal {@code StockReceiptService.receive}
 * path (so inventory + provisional-COGS reconciliation fire); rejection
 * cancels the draft. Mirrors {@code BillDraftingController}.
 */
@RestController
@RequestMapping("/api/v1/ai/grn-drafts")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.AI_INBOX)
public class GrnDraftingController {

    private final GrnDraftingService grnDraftingService;
    private final GrnScanService grnScanService;

    /** One-shot vision OCR — client gets back the parsed lines to edit before drafting. */
    @PostMapping("/scan")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
    public ResponseEntity<ApiResponse<GrnScanResponse>> scan(
            @RequestBody Map<String, String> body) {
        String base64Image = body == null ? null : body.get("base64Image");
        if (base64Image == null || base64Image.isBlank()) {
            base64Image = body == null ? null : body.get("image");
        }
        String mediaType = body == null ? null : body.get("mediaType");
        GrnScanResponse result = grnScanService.scanGrn(base64Image, mediaType);
        return ResponseEntity.ok(ApiResponse.ok(result));
    }

    /** Draft a DRAFT goods receipt + AI Inbox suggestion from scanned data. */
    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
    public ResponseEntity<ApiResponse<GrnDraftResult>> draft(
            @Valid @RequestBody GrnDraftFromScanRequest request) {
        GrnDraftResult result = grnDraftingService.draftFromScan(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(result));
    }

    /** Approve a drafted GRN — posts the receipt and updates stock. */
    @PostMapping("/{suggestionId}/approve")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
    public ResponseEntity<ApiResponse<GrnDraftResult>> approve(@PathVariable UUID suggestionId) {
        GrnDraftResult result = grnDraftingService.approve(suggestionId);
        return ResponseEntity.ok(ApiResponse.ok(result, "GRN received — stock posted"));
    }

    /** Reject a drafted GRN — cancels the draft. */
    @PostMapping("/{suggestionId}/reject")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
    public ResponseEntity<ApiResponse<Void>> reject(
            @PathVariable UUID suggestionId,
            @RequestBody(required = false) Map<String, String> body) {
        String reason = body != null ? body.get("reason") : null;
        grnDraftingService.reject(suggestionId, reason);
        return ResponseEntity.ok(ApiResponse.<Void>ok(null, "Drafted GRN rejected"));
    }
}
