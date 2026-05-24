package com.katasticho.erp.procurement.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.procurement.dto.DebitNoteRequest;
import com.katasticho.erp.procurement.dto.DebitNoteResponse;
import com.katasticho.erp.procurement.service.DebitNoteService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/debit-notes")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
public class DebitNoteController {

    private final DebitNoteService debitNoteService;

    @PostMapping
    public ResponseEntity<ApiResponse<DebitNoteResponse>> create(
            @Valid @RequestBody DebitNoteRequest request) {
        DebitNoteResponse response = debitNoteService.create(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(response));
    }

    @PostMapping("/{id}/submit")
    public ResponseEntity<ApiResponse<DebitNoteResponse>> submit(@PathVariable UUID id) {
        DebitNoteResponse response = debitNoteService.submit(id);
        return ResponseEntity.ok(ApiResponse.ok(response, "Debit note submitted"));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<Page<DebitNoteResponse>>> list(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) UUID supplierId,
            @PageableDefault(size = 20, sort = "noteDate") Pageable pageable) {
        Page<DebitNoteResponse> page = debitNoteService.list(status, supplierId, pageable);
        return ResponseEntity.ok(ApiResponse.ok(page));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<DebitNoteResponse>> getById(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(debitNoteService.getById(id)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {
        debitNoteService.delete(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Debit note deleted"));
    }
}
