package com.katasticho.erp.ai.controller;

import com.katasticho.erp.ai.dto.AgentChatDtos;
import com.katasticho.erp.ai.dto.AiQueryRequest;
import com.katasticho.erp.ai.dto.AiQueryResponse;
import com.katasticho.erp.ai.dto.AiAgentRunResponse;
import com.katasticho.erp.ai.dto.AiSuggestionResponse;
import com.katasticho.erp.ai.dto.AiSuggestionReviewRequest;
import com.katasticho.erp.ai.dto.BillScanRequest;
import com.katasticho.erp.ai.dto.BillScanResponse;
import com.katasticho.erp.ai.dto.AiInboxSummaryResponse;
import com.katasticho.erp.ai.dto.ItemScanResponse;
import com.katasticho.erp.ai.service.AiSuggestionService;
import com.katasticho.erp.ai.service.AiTrainingExportService;
import com.katasticho.erp.ai.service.BillScanService;
import com.katasticho.erp.ai.service.ConversationalAgentService;
import com.katasticho.erp.ai.service.ItemScanService;
import com.katasticho.erp.ai.service.NlpQueryService;
import com.katasticho.erp.ai.service.ProactiveAgentService;
import com.katasticho.erp.ai.service.RuleBasedAiAgentService;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.dto.PagedResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/ai")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.AI_INBOX)
public class AiController {

    private final NlpQueryService nlpQueryService;
    private final BillScanService billScanService;
    private final ItemScanService itemScanService;
    private final AiSuggestionService aiSuggestionService;
    private final RuleBasedAiAgentService ruleBasedAiAgentService;
    private final ProactiveAgentService proactiveAgentService;
    private final AiTrainingExportService aiTrainingExportService;
    private final ConversationalAgentService conversationalAgentService;

    /** Summary of how much fine-tuning data has accumulated. */
    @GetMapping("/training/summary")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<java.util.Map<String, Object>>> trainingSummary() {
        return ResponseEntity.ok(ApiResponse.ok(aiTrainingExportService.summary()));
    }

    /** Export human-reviewed AI decisions as chat-format JSONL for LoRA/SFT fine-tuning. */
    @GetMapping(value = "/training/export", produces = "application/x-ndjson")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<String> exportTraining(
            @RequestParam(required = false) String taskType,
            @RequestParam(defaultValue = "true") boolean goodOnly) {
        String jsonl = aiTrainingExportService.exportJsonl(taskType, goodOnly);
        return ResponseEntity.ok()
                .header("Content-Disposition", "attachment; filename=\"katasticho-finetune.jsonl\"")
                .body(jsonl);
    }

    @GetMapping("/suggestions")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<PagedResponse<AiSuggestionResponse>>> listSuggestions(
            @RequestParam(required = false) String status,
            Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(aiSuggestionService.list(status, pageable)));
    }

    @GetMapping("/suggestions/summary")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<AiInboxSummaryResponse>> suggestionSummary() {
        return ResponseEntity.ok(ApiResponse.ok(aiSuggestionService.summary()));
    }

    @GetMapping("/suggestions/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<AiSuggestionResponse>> getSuggestion(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(aiSuggestionService.get(id)));
    }

    @PostMapping("/suggestions/{id}/review")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<AiSuggestionResponse>> reviewSuggestion(
            @PathVariable UUID id,
            @Valid @RequestBody AiSuggestionReviewRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(aiSuggestionService.review(id, request)));
    }

    @PostMapping("/agents/rule-checks/run")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<AiAgentRunResponse>> runRuleChecks(
            @RequestParam(required = false) Integer days) {
        return ResponseEntity.ok(ApiResponse.ok(ruleBasedAiAgentService.runRuleChecks(days)));
    }

    /** Run the proactive sweep now (collections, month-close, anomalies). */
    @PostMapping("/agents/proactive/run")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<ProactiveAgentService.ProactiveRunResult>> runProactive() {
        return ResponseEntity.ok(ApiResponse.ok(proactiveAgentService.runAll()));
    }

    /**
     * POST /api/v1/ai/query
     * Natural language query → SQL → results → human-readable answer.
     * Read-only. Uses Claude to generate safe SELECT queries.
     */
    @PostMapping("/query")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<AiQueryResponse>> query(
            @Valid @RequestBody AiQueryRequest request) {
        AiQueryResponse response = nlpQueryService.processQuery(request.message());
        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    /**
     * POST /api/v1/ai/agent
     * Conversational agent with tool-use: one message → the agent picks a tool
     * (query your data, draft a transaction, list overdue customers) and runs it
     * through existing services. Write tools only ever create DRAFTS for approval.
     */
    @PostMapping("/agent")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<AgentChatDtos.AgentChatResponse>> agent(
            @Valid @RequestBody AgentChatDtos.AgentChatRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(conversationalAgentService.chat(request.message())));
    }

    /**
     * POST /api/v1/ai/scan-bill
     * Upload a bill image (base64) → Claude Vision extracts structured data.
     * Returns vendor, items, GST breakdown for pre-filling invoice forms.
     */
    @PostMapping("/scan-bill")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<BillScanResponse>> scanBill(
            @Valid @RequestBody BillScanRequest request) {
        BillScanResponse response = billScanService.scanBill(
                request.image(), request.effectiveMediaType());
        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    /**
     * POST /api/v1/ai/scan-product-label
     * Upload a product label image → Claude Vision extracts item details.
     * Returns name, barcode, MRP, brand, category, etc. for pre-filling item form.
     */
    @PostMapping("/scan-product-label")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<ItemScanResponse>> scanProductLabel(
            @Valid @RequestBody BillScanRequest request) {
        ItemScanResponse response = itemScanService.scanProductLabel(
                request.image(), request.effectiveMediaType());
        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    /**
     * POST /api/v1/ai/scan-purchase-invoice
     * Upload a purchase invoice image → extracts all line items with prices.
     * Returns items list for bulk creation with purchase prices pre-filled.
     */
    @PostMapping("/scan-purchase-invoice")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<ItemScanResponse>> scanPurchaseInvoice(
            @Valid @RequestBody BillScanRequest request) {
        ItemScanResponse response = itemScanService.scanPurchaseInvoice(
                request.image(), request.effectiveMediaType());
        return ResponseEntity.ok(ApiResponse.ok(response));
    }
}
