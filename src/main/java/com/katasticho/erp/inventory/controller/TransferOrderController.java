package com.katasticho.erp.inventory.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.dto.PagedResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.inventory.dto.CreateTransferOrderRequest;
import com.katasticho.erp.inventory.dto.TransferOrderResponse;
import com.katasticho.erp.inventory.service.TransferOrderService;
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
@RequestMapping("/api/v1/transfer-orders")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.INVENTORY)
public class TransferOrderController {

    private final TransferOrderService transferOrderService;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<TransferOrderResponse>> create(
            @Valid @RequestBody CreateTransferOrderRequest request) {
        TransferOrderResponse response = transferOrderService.create(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(response));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<TransferOrderResponse>>> list(Pageable pageable) {
        Page<TransferOrderResponse> page = transferOrderService.list(pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<TransferOrderResponse>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(transferOrderService.get(id)));
    }

    @PostMapping("/{id}/ship")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<TransferOrderResponse>> ship(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(transferOrderService.ship(id)));
    }

    @PostMapping("/{id}/receive")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<TransferOrderResponse>> receive(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(transferOrderService.receive(id)));
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> cancel(@PathVariable UUID id) {
        transferOrderService.cancel(id);
        return ResponseEntity.ok(ApiResponse.ok(null));
    }
}
