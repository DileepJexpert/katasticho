package com.katasticho.erp.sales.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.dto.PagedResponse;
import com.katasticho.erp.sales.dto.CreateDeliveryChallanRequest;
import com.katasticho.erp.sales.dto.DeliveryChallanResponse;
import com.katasticho.erp.sales.service.DeliveryChallanPdfService;
import com.katasticho.erp.sales.service.DeliveryChallanService;
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
@RequestMapping("/api/v1/delivery-challans")
@RequiredArgsConstructor
public class DeliveryChallanController {

    private final DeliveryChallanService challanService;
    private final DeliveryChallanPdfService challanPdfService;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<DeliveryChallanResponse>> create(
            @Valid @RequestBody CreateDeliveryChallanRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(challanService.create(request)));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<DeliveryChallanResponse>>> list(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) UUID salesOrderId,
            Pageable pageable) {
        Page<DeliveryChallanResponse> page = challanService.list(status, salesOrderId, pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<DeliveryChallanResponse>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(challanService.get(id)));
    }

    @GetMapping("/{id}/pdf")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<byte[]> downloadPdf(@PathVariable UUID id) {
        DeliveryChallanResponse dc = challanService.get(id);
        byte[] pdf = challanPdfService.generatePdf(dc);
        String filename = "challan-" + dc.challanNumber().replaceAll("[/\\\\:*?\"<>|]", "-") + ".pdf";
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_PDF)
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .body(pdf);
    }

    @PostMapping("/{id}/dispatch")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<DeliveryChallanResponse>> dispatch(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                challanService.dispatch(id), "Challan dispatched — stock deducted"));
    }

    @PostMapping("/{id}/deliver")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<DeliveryChallanResponse>> markDelivered(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                challanService.markDelivered(id), "Challan marked as delivered"));
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> cancel(@PathVariable UUID id) {
        challanService.cancel(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Challan cancelled"));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {
        challanService.delete(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Challan deleted"));
    }

    @GetMapping("/by-sales-order/{salesOrderId}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<DeliveryChallanResponse>>> getBySalesOrder(
            @PathVariable UUID salesOrderId) {
        return ResponseEntity.ok(ApiResponse.ok(challanService.getChallansForSalesOrder(salesOrderId)));
    }
}
