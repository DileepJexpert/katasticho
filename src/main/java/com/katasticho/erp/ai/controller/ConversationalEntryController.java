package com.katasticho.erp.ai.controller;

import com.katasticho.erp.ai.dto.ConversationalEntryDtos.EntryDraftRequest;
import com.katasticho.erp.ai.dto.ConversationalEntryDtos.EntryDraftResult;
import com.katasticho.erp.ai.dto.ConversationalEntryDtos.EntryRejectRequest;
import com.katasticho.erp.ai.service.ConversationalEntryService;
import com.katasticho.erp.common.dto.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/**
 * Conversational entry — "type a sentence, get a drafted transaction".
 * Drafts are surfaced in the AI Inbox and only post when a human approves.
 */
@RestController
@RequestMapping("/api/v1/ai/entry")
@RequiredArgsConstructor
public class ConversationalEntryController {

    private final ConversationalEntryService service;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<EntryDraftResult>> draft(
            @Valid @RequestBody EntryDraftRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(service.draftFromText(request.text())));
    }

    @PostMapping("/{suggestionId}/approve")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<EntryDraftResult>> approve(@PathVariable UUID suggestionId) {
        return ResponseEntity.ok(ApiResponse.ok(service.approve(suggestionId), "Entry posted"));
    }

    @PostMapping("/{suggestionId}/reject")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> reject(
            @PathVariable UUID suggestionId,
            @RequestBody(required = false) EntryRejectRequest request) {
        service.reject(suggestionId, request == null ? null : request.reason());
        return ResponseEntity.ok(ApiResponse.ok(null, "Draft discarded"));
    }
}
