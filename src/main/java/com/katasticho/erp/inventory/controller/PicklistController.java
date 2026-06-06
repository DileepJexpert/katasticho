package com.katasticho.erp.inventory.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.dto.PagedResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.inventory.dto.CreatePicklistRequest;
import com.katasticho.erp.inventory.dto.PicklistResponse;
import com.katasticho.erp.inventory.dto.UpdatePicklistLineRequest;
import com.katasticho.erp.inventory.service.PicklistService;
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
@RequestMapping("/api/v1/picklists")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.INVENTORY)
public class PicklistController {

    private final PicklistService picklistService;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<PicklistResponse>> create(
            @Valid @RequestBody CreatePicklistRequest request) {
        PicklistResponse response = picklistService.create(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(response));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<PicklistResponse>>> list(Pageable pageable) {
        Page<PicklistResponse> page = picklistService.list(pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<PicklistResponse>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(picklistService.get(id)));
    }

    @GetMapping("/by-sales-order/{salesOrderId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<PicklistResponse>>> listBySalesOrder(
            @PathVariable UUID salesOrderId) {
        return ResponseEntity.ok(ApiResponse.ok(picklistService.listBySalesOrder(salesOrderId)));
    }

    @PostMapping("/{id}/start")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<PicklistResponse>> startPicking(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(picklistService.startPicking(id)));
    }

    @PutMapping("/{id}/lines")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<PicklistResponse>> updatePickedQuantities(
            @PathVariable UUID id,
            @Valid @RequestBody UpdatePicklistLineRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(picklistService.updatePickedQuantities(id, request)));
    }

    @PostMapping("/{id}/complete")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<PicklistResponse>> complete(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(picklistService.complete(id)));
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> cancel(@PathVariable UUID id) {
        picklistService.cancel(id);
        return ResponseEntity.ok(ApiResponse.ok(null));
    }
}
