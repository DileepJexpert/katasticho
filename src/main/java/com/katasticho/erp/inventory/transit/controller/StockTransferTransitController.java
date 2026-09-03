package com.katasticho.erp.inventory.transit.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.inventory.transit.dto.DispatchCreateRequest;
import com.katasticho.erp.inventory.transit.dto.TransferOrderDispatchResponse;
import com.katasticho.erp.inventory.transit.dto.TransitPingRequest;
import com.katasticho.erp.inventory.transit.service.StockTransferTransitService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/inventory/transfers/transit")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.INVENTORY)
@PreAuthorize("hasAnyRole('OWNER', 'ADMIN', 'ACCOUNTANT', 'OPERATOR')")
public class StockTransferTransitController {

    private final StockTransferTransitService service;

    @GetMapping
    public ApiResponse<List<TransferOrderDispatchResponse>> listDispatches(
            @RequestParam(required = false) String status) {
        return ApiResponse.ok(service.listDispatches(status));
    }

    @GetMapping("/{id}")
    public ApiResponse<TransferOrderDispatchResponse> getDispatch(@PathVariable UUID id) {
        return ApiResponse.ok(service.getDispatch(id));
    }

    @PostMapping
    public ApiResponse<TransferOrderDispatchResponse> createDispatch(
            @Valid @RequestBody DispatchCreateRequest request) {
        return ApiResponse.ok(service.createDispatch(request));
    }

    @PostMapping("/{id}/ping")
    public ApiResponse<TransferOrderDispatchResponse> recordPing(
            @PathVariable UUID id,
            @Valid @RequestBody TransitPingRequest request) {
        return ApiResponse.ok(service.recordPing(id, request));
    }

    @PostMapping("/{id}/deliver")
    public ApiResponse<TransferOrderDispatchResponse> markDelivered(@PathVariable UUID id) {
        return ApiResponse.ok(service.markDelivered(id));
    }

    @PostMapping("/{id}/receive")
    public ApiResponse<TransferOrderDispatchResponse> receiveAtDestination(@PathVariable UUID id) {
        return ApiResponse.ok(service.receiveAtDestination(id));
    }
}
