package com.katasticho.erp.recurring.controller;

import com.katasticho.erp.ar.dto.InvoiceResponse;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.dto.PagedResponse;
import com.katasticho.erp.recurring.dto.CreateRecurringInvoiceRequest;
import com.katasticho.erp.recurring.dto.GeneratedInvoiceResponse;
import com.katasticho.erp.recurring.dto.RecurringInvoiceResponse;
import com.katasticho.erp.recurring.dto.UpdateRecurringInvoiceRequest;
import com.katasticho.erp.recurring.service.RecurringInvoiceService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/recurring-invoices")
@RequiredArgsConstructor
public class RecurringInvoiceController {

    private final RecurringInvoiceService recurringInvoiceService;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<RecurringInvoiceResponse>> create(
            @Valid @RequestBody CreateRecurringInvoiceRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(recurringInvoiceService.createTemplate(request)));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<RecurringInvoiceResponse>>> list(
            @RequestParam(required = false) String status,
            Pageable pageable) {
        Page<RecurringInvoiceResponse> page = recurringInvoiceService.listTemplates(status, pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<RecurringInvoiceResponse>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(recurringInvoiceService.getTemplate(id)));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<RecurringInvoiceResponse>> update(
            @PathVariable UUID id,
            @Valid @RequestBody UpdateRecurringInvoiceRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(recurringInvoiceService.updateTemplate(id, request)));
    }

    @PostMapping("/{id}/stop")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<RecurringInvoiceResponse>> stop(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                recurringInvoiceService.stopTemplate(id), "Recurring invoice stopped"));
    }

    @PostMapping("/{id}/resume")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<RecurringInvoiceResponse>> resume(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                recurringInvoiceService.resumeTemplate(id), "Recurring invoice resumed"));
    }

    @GetMapping("/{id}/generated-invoices")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<GeneratedInvoiceResponse>>> generatedInvoices(
            @PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                recurringInvoiceService.listGeneratedInvoices(id)));
    }

    /**
     * Manual trigger — useful for "run now" actions on the detail
     * screen and for dev/debug scenarios where waiting for the 06:00
     * cron isn't practical.
     */
    @PostMapping("/{id}/generate-now")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<InvoiceResponse>> generateNow(@PathVariable UUID id) {
        InvoiceResponse invoice = recurringInvoiceService.generateFromTemplate(id);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(invoice));
    }
}
