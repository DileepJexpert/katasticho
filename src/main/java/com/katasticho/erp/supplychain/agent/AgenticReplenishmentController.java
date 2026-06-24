package com.katasticho.erp.supplychain.agent;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.supplychain.agent.AgenticReplenishmentService.ApproveResult;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

/**
 * REST surface for advisory agentic replenishment.
 *
 * <p>The {@code /run} endpoint scans the org now (manual trigger — also runs
 * nightly via {@code AgenticReplenishmentJob}). Approve drafts a real PR
 * (default) or DRAFT PO; reject closes the suggestion without creating any
 * document. <strong>Nothing here ever posts a real PR/PO without explicit
 * human approval through this controller.</strong>
 */
@RestController
@RequestMapping("/api/v1/ai/replenishment-drafts")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.AI_INBOX)
public class AgenticReplenishmentController {

    private final AgenticReplenishmentService service;

    /** Run the replenishment scan now for the current org. */
    @PostMapping("/run")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> run() {
        int created = service.runForOrg();
        return ResponseEntity.ok(ApiResponse.ok(
                Map.of("created", created),
                "Replenishment scan complete — " + created + " new suggestion(s)"));
    }

    /**
     * Approve a drafted replenishment. Body: optional {@code docType} —
     * one of {@code PURCHASE_REQUISITION} (default) or {@code PURCHASE_ORDER}.
     */
    @PostMapping("/{suggestionId}/approve")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
    public ResponseEntity<ApiResponse<ApproveResult>> approve(
            @PathVariable UUID suggestionId,
            @RequestBody(required = false) Map<String, String> body) {
        String docType = body != null ? body.get("docType") : null;
        ApproveResult result = service.approve(suggestionId, docType);
        String message = "Drafted " + result.docType()
                + (result.createdDocNumber() != null ? " " + result.createdDocNumber() : "")
                + " — review in Procurement";
        return ResponseEntity.ok(ApiResponse.ok(result, message));
    }

    /** Reject a drafted replenishment — no document created. */
    @PostMapping("/{suggestionId}/reject")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
    public ResponseEntity<ApiResponse<Void>> reject(
            @PathVariable UUID suggestionId,
            @RequestBody(required = false) Map<String, String> body) {
        String reason = body != null ? body.get("reason") : null;
        service.reject(suggestionId, reason);
        return ResponseEntity.ok(ApiResponse.<Void>ok(null, "Replenishment suggestion rejected"));
    }
}
