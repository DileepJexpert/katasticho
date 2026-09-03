package com.katasticho.erp.banking.reconciliation.controller;

import com.katasticho.erp.banking.reconciliation.dto.AutoMatchRunRequest;
import com.katasticho.erp.banking.reconciliation.dto.AutoMatchSuggestionResponse;
import com.katasticho.erp.banking.reconciliation.service.BankSmartAutoMatchService;
import com.katasticho.erp.common.dto.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/banking/auto-match")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER', 'ADMIN', 'ACCOUNTANT')")
public class BankAutoMatchController {

    private final BankSmartAutoMatchService service;

    @GetMapping("/suggestions")
    public ApiResponse<List<AutoMatchSuggestionResponse>> listSuggestions(
            @RequestParam UUID bankAccountId,
            @RequestParam(required = false) String status) {
        return ApiResponse.ok(service.listSuggestions(bankAccountId, status));
    }

    @PostMapping("/run")
    public ApiResponse<List<AutoMatchSuggestionResponse>> runAutoMatch(
            @Valid @RequestBody AutoMatchRunRequest request) {
        return ApiResponse.ok(service.runAutoMatch(request));
    }

    @PostMapping("/suggestions/{id}/accept")
    public ApiResponse<AutoMatchSuggestionResponse> acceptSuggestion(@PathVariable UUID id) {
        return ApiResponse.ok(service.acceptSuggestion(id));
    }

    @PostMapping("/suggestions/{id}/reject")
    public ApiResponse<AutoMatchSuggestionResponse> rejectSuggestion(@PathVariable UUID id) {
        return ApiResponse.ok(service.rejectSuggestion(id));
    }

    @PostMapping("/bulk-accept")
    public ApiResponse<Map<String, Object>> bulkAccept(
            @RequestParam UUID bankAccountId,
            @RequestParam(defaultValue = "80") int minScore) {
        int accepted = service.acceptAllHighConfidence(bankAccountId, minScore);
        return ApiResponse.ok(Map.of("acceptedCount", accepted, "minScore", minScore));
    }
}