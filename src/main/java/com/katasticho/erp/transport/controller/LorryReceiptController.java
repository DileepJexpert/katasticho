package com.katasticho.erp.transport.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.transport.dto.TransportDtos.*;
import com.katasticho.erp.transport.service.LorryReceiptService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Lorry Receipts (consignment notes) for road/GTA freight + freight billing.
 */
@RestController
@RequestMapping("/api/v1/transport/lorry-receipts")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.TRANSPORT)
public class LorryReceiptController {

    private final LorryReceiptService service;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<LorryReceiptResponse>> create(
            @Valid @RequestBody CreateLorryReceiptRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(service.create(request)));
    }

    @PostMapping("/{id}/issue")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<LorryReceiptResponse>> issue(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.issue(id), "LR issued"));
    }

    @PostMapping("/{id}/deliver")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<LorryReceiptResponse>> deliver(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.markDelivered(id), "LR marked delivered"));
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<LorryReceiptResponse>> cancel(
            @PathVariable UUID id, @RequestBody(required = false) Map<String, String> body) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.cancel(id, body == null ? null : body.get("reason")), "LR cancelled"));
    }

    /** Raise a DRAFT purchase bill to the transporter for this LR's freight. */
    @PostMapping("/{id}/bill-freight")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<BillFreightResult>> billFreight(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.billFreight(id),
                "Freight billed to transporter (draft)"));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<LorryReceiptResponse>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.get(id)));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<LorryReceiptResponse>>> list(
            @RequestParam(required = false) String status) {
        return ResponseEntity.ok(ApiResponse.ok(service.list(status)));
    }
}
