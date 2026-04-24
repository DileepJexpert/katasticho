package com.katasticho.erp.accounting.controller;

import com.katasticho.erp.accounting.dto.JournalEntryResponse;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.dto.PagedResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/journal-entries")
@RequiredArgsConstructor
public class JournalController {

    private final JournalService journalService;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<JournalEntryResponse>> createJournal(@Valid @RequestBody JournalPostRequest request) {
        JournalEntry entry = journalService.postJournal(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(journalService.toResponse(entry)));
    }

    @PostMapping("/{id}/post")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<JournalEntryResponse>> postJournal(@PathVariable UUID id) {
        JournalEntry entry = journalService.postEntry(id);
        return ResponseEntity.ok(ApiResponse.ok(journalService.toResponse(entry), "Journal entry posted"));
    }

    @PostMapping("/{id}/reverse")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<JournalEntryResponse>> reverseJournal(@PathVariable UUID id) {
        JournalEntry reversal = journalService.reverseEntry(id);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(journalService.toResponse(reversal)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<JournalEntryResponse>> getJournal(@PathVariable UUID id) {
        JournalEntry entry = journalService.getEntry(id, TenantContext.getCurrentOrgId());
        return ResponseEntity.ok(ApiResponse.ok(journalService.toResponse(entry)));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<JournalEntryResponse>>> listJournals(
            @RequestParam(required = false) String sourceModule,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateFrom,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateTo,
            @RequestParam(required = false) String search,
            Pageable pageable) {
        Page<JournalEntry> page = journalService.listEntries(
                TenantContext.getCurrentOrgId(), sourceModule, dateFrom, dateTo, search, pageable);
        Page<JournalEntryResponse> responsePage = page.map(journalService::toResponse);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(responsePage)));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> deleteJournal(@PathVariable UUID id) {
        journalService.deleteEntry(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Journal entry deleted"));
    }
}
