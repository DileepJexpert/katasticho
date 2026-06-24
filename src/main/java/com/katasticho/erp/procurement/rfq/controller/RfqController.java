package com.katasticho.erp.procurement.rfq.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.procurement.rfq.dto.AwardResponse;
import com.katasticho.erp.procurement.rfq.dto.CompareQuotesResponse;
import com.katasticho.erp.procurement.rfq.dto.CreateRfqRequest;
import com.katasticho.erp.procurement.rfq.dto.QuoteResponse;
import com.katasticho.erp.procurement.rfq.dto.RecordQuoteRequest;
import com.katasticho.erp.procurement.rfq.dto.RfqResponse;
import com.katasticho.erp.procurement.rfq.service.RfqService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/procurement/rfq")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.SUPPLY_CHAIN)
public class RfqController {

    private final RfqService rfqService;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
    public ResponseEntity<ApiResponse<RfqResponse>> create(@Valid @RequestBody CreateRfqRequest request) {
        RfqResponse response = rfqService.createRfq(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(response));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<RfqResponse>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(rfqService.get(id)));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<Page<RfqResponse>>> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Page<RfqResponse> result = rfqService.list(PageRequest.of(page, size));
        return ResponseEntity.ok(ApiResponse.ok(result));
    }

    @PostMapping("/{id}/send")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
    public ResponseEntity<ApiResponse<RfqResponse>> send(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(rfqService.send(id), "RFQ sent"));
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
    public ResponseEntity<ApiResponse<RfqResponse>> cancel(
            @PathVariable UUID id,
            @RequestBody(required = false) Map<String, String> body) {
        String reason = body != null ? body.get("reason") : null;
        return ResponseEntity.ok(ApiResponse.ok(rfqService.cancel(id, reason), "RFQ cancelled"));
    }

    @PostMapping("/{id}/quotes")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
    public ResponseEntity<ApiResponse<QuoteResponse>> recordQuote(
            @PathVariable("id") UUID rfqId,
            @Valid @RequestBody RecordQuoteRequest request) {
        QuoteResponse response = rfqService.recordQuote(rfqId, request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(response));
    }

    @GetMapping("/{id}/quotes")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<QuoteResponse>>> listQuotes(@PathVariable("id") UUID rfqId) {
        return ResponseEntity.ok(ApiResponse.ok(rfqService.listQuotes(rfqId)));
    }

    @GetMapping("/{id}/compare")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<CompareQuotesResponse>> compare(@PathVariable("id") UUID rfqId) {
        return ResponseEntity.ok(ApiResponse.ok(rfqService.compareQuotes(rfqId)));
    }

    @PostMapping("/{id}/award")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<AwardResponse>> award(
            @PathVariable("id") UUID rfqId,
            @RequestBody Map<String, UUID> body) {
        UUID winningQuoteId = body.get("winningQuoteId");
        if (winningQuoteId == null) {
            return ResponseEntity.badRequest().body(ApiResponse.error("winningQuoteId is required"));
        }
        return ResponseEntity.ok(ApiResponse.ok(rfqService.award(rfqId, winningQuoteId), "RFQ awarded"));
    }
}
