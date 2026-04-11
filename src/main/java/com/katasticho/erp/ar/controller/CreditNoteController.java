package com.katasticho.erp.ar.controller;

import com.katasticho.erp.ar.dto.CreateCreditNoteRequest;
import com.katasticho.erp.ar.dto.CreditNoteResponse;
import com.katasticho.erp.ar.entity.CreditNote;
import com.katasticho.erp.ar.service.CreditNoteService;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.dto.PagedResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/credit-notes")
@RequiredArgsConstructor
public class CreditNoteController {

    private final CreditNoteService creditNoteService;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<CreditNoteResponse>> createCreditNote(@Valid @RequestBody CreateCreditNoteRequest request) {
        CreditNote cn = creditNoteService.createCreditNote(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(creditNoteService.toResponse(cn)));
    }

    @PostMapping("/{id}/issue")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<CreditNoteResponse>> issueCreditNote(@PathVariable UUID id) {
        CreditNote cn = creditNoteService.issueCreditNote(id);
        return ResponseEntity.ok(ApiResponse.ok(creditNoteService.toResponse(cn), "Credit note issued and journal posted"));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<CreditNoteResponse>> getCreditNote(@PathVariable UUID id) {
        CreditNote cn = creditNoteService.getCreditNote(id);
        return ResponseEntity.ok(ApiResponse.ok(creditNoteService.toResponse(cn)));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<CreditNoteResponse>>> listCreditNotes(Pageable pageable) {
        Page<CreditNote> page = creditNoteService.listCreditNotes(pageable);
        Page<CreditNoteResponse> responsePage = page.map(creditNoteService::toResponse);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(responsePage)));
    }
}
