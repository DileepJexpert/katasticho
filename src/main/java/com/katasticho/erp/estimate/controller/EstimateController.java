package com.katasticho.erp.estimate.controller;

import com.katasticho.erp.ar.dto.InvoiceResponse;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.dto.PagedResponse;
import com.katasticho.erp.estimate.dto.CreateEstimateRequest;
import com.katasticho.erp.estimate.dto.EstimateResponse;
import com.katasticho.erp.estimate.dto.UpdateEstimateRequest;
import com.katasticho.erp.estimate.service.EstimatePdfService;
import com.katasticho.erp.estimate.service.EstimateService;
import com.katasticho.erp.common.service.DocumentShareService;
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

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/estimates")
@RequiredArgsConstructor
public class EstimateController {

    private final EstimateService estimateService;
    private final DocumentShareService documentShareService;
    private final EstimatePdfService estimatePdfService;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<EstimateResponse>> create(
            @Valid @RequestBody CreateEstimateRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(estimateService.createEstimate(request)));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<EstimateResponse>>> list(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) UUID contactId,
            Pageable pageable) {
        Page<EstimateResponse> page = estimateService.listEstimates(status, contactId, pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<EstimateResponse>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(estimateService.getEstimate(id)));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<EstimateResponse>> update(
            @PathVariable UUID id,
            @Valid @RequestBody UpdateEstimateRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(estimateService.updateEstimate(id, request)));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {
        estimateService.deleteEstimate(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Estimate deleted"));
    }

    @PostMapping("/{id}/send")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<EstimateResponse>> send(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                estimateService.sendEstimate(id), "Estimate sent"));
    }

    @PostMapping("/{id}/accept")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<EstimateResponse>> accept(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                estimateService.acceptEstimate(id), "Estimate accepted"));
    }

    @PostMapping("/{id}/decline")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<EstimateResponse>> decline(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                estimateService.declineEstimate(id), "Estimate declined"));
    }

    @PostMapping("/{id}/convert-to-invoice")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<InvoiceResponse>> convert(@PathVariable UUID id) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(estimateService.convertToInvoice(id)));
    }

    @GetMapping("/{id}/pdf")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<byte[]> downloadPdf(@PathVariable UUID id) {
        EstimateResponse estimate = estimateService.getEstimate(id);
        byte[] pdf = estimatePdfService.generatePdf(estimate);
        String filename = "estimate-" + estimate.estimateNumber().replaceAll("[/\\\\:*?\"<>|]", "-") + ".pdf";
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_PDF)
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .body(pdf);
    }

    @GetMapping("/{id}/whatsapp-link")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<Map<String, String>>> whatsappLink(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(documentShareService.shareEstimate(id)));
    }
}
