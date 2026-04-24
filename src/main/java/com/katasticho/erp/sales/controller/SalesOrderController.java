package com.katasticho.erp.sales.controller;

import com.katasticho.erp.ar.dto.InvoiceResponse;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.dto.PagedResponse;
import com.katasticho.erp.sales.dto.*;
import com.katasticho.erp.sales.service.SalesOrderPdfService;
import com.katasticho.erp.sales.service.SalesOrderService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/sales-orders")
@RequiredArgsConstructor
public class SalesOrderController {

    private final SalesOrderService salesOrderService;
    private final SalesOrderPdfService salesOrderPdfService;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<SalesOrderResponse>> create(
            @Valid @RequestBody CreateSalesOrderRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(salesOrderService.create(request)));
    }

    @PostMapping("/from-estimate/{estimateId}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<SalesOrderResponse>> createFromEstimate(
            @PathVariable UUID estimateId) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(salesOrderService.createFromEstimate(estimateId)));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<SalesOrderResponse>>> list(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) UUID contactId,
            @RequestParam(required = false) UUID branchId,
            Pageable pageable) {
        Page<SalesOrderResponse> page = salesOrderService.list(status, contactId, branchId, pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<SalesOrderResponse>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(salesOrderService.get(id)));
    }

    @GetMapping("/{id}/pdf")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<byte[]> downloadPdf(@PathVariable UUID id) {
        SalesOrderResponse so = salesOrderService.get(id);
        byte[] pdf = salesOrderPdfService.generatePdf(so);
        String filename = "sales-order-" + so.salesOrderNumber().replaceAll("[/\\\\:*?\"<>|]", "-") + ".pdf";
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_PDF)
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .body(pdf);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<SalesOrderResponse>> update(
            @PathVariable UUID id,
            @Valid @RequestBody UpdateSalesOrderRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(salesOrderService.update(id, request)));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {
        salesOrderService.delete(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Sales order deleted"));
    }

    @PostMapping("/{id}/confirm")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<SalesOrderResponse>> confirm(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                salesOrderService.confirm(id), "Sales order confirmed"));
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<SalesOrderResponse>> cancel(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                salesOrderService.cancel(id), "Sales order cancelled"));
    }

    @PostMapping("/{id}/convert-to-invoice")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<InvoiceResponse>> convertToInvoice(
            @PathVariable UUID id,
            @Valid @RequestBody ConvertToInvoiceRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(salesOrderService.convertToInvoice(id, request)));
    }

    @GetMapping("/{id}/reservations")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<StockReservationResponse>>> getReservations(
            @PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(salesOrderService.getReservations(id)));
    }

    @GetMapping("/{id}/invoices")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<InvoiceResponse>>> getLinkedInvoices(
            @PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(salesOrderService.getLinkedInvoices(id)));
    }
}
