package com.katasticho.erp.ai.controller;

import com.katasticho.erp.ai.dto.CategorySuggestion;
import com.katasticho.erp.ai.service.TransactionCategorizationService;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

/**
 * Auto-categorize transactions agent — suggests the GL account for an
 * un-categorized purchase line from how this vendor was booked before.
 *
 * <p>{@code GET /categorize} is called as the operator picks a vendor on a bill
 * line; {@code POST /categorize/backfill} seeds the learned memory from already
 * posted bills so suggestions work before any AI Inbox approval has happened.
 */
@RestController
@RequestMapping("/api/v1/ai/categorize")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.AI_INBOX)
public class TransactionCategorizationController {

    private final TransactionCategorizationService service;

    /** Suggest an account for a vendor (+ optional HSN). 200 with null data when nothing learned. */
    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<CategorySuggestion>> suggest(
            @RequestParam UUID contactId,
            @RequestParam(required = false) String hsn) {
        return ResponseEntity.ok(ApiResponse.ok(service.suggest(contactId, hsn).orElse(null)));
    }

    /** Learn vendor→account patterns from posted bills in the last N days (default 365). */
    @PostMapping("/backfill")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> backfill(
            @RequestParam(defaultValue = "365") int lookbackDays) {
        int learned = service.backfillFromHistory(lookbackDays);
        return ResponseEntity.ok(ApiResponse.ok(
                Map.of("patternsLearned", learned, "lookbackDays", lookbackDays),
                learned + " vendor-account pattern(s) learned from history"));
    }
}
