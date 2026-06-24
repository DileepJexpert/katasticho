package com.katasticho.erp.procurement.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.procurement.dto.CreateSupplierRateContractRequest;
import com.katasticho.erp.procurement.dto.SupplierRateContractResponse;
import com.katasticho.erp.procurement.service.SupplierRateContractService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/procurement/rate-contracts")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.SUPPLY_CHAIN)
public class SupplierRateContractController {

    private final SupplierRateContractService service;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
    public ResponseEntity<ApiResponse<SupplierRateContractResponse>> create(
            @Valid @RequestBody CreateSupplierRateContractRequest request) {
        SupplierRateContractResponse response = service.create(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(response));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<SupplierRateContractResponse>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.get(id)));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<Page<SupplierRateContractResponse>>> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) UUID supplierContactId) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.list(PageRequest.of(page, size), supplierContactId)));
    }

    @GetMapping("/active")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<SupplierRateContractResponse>>> listActive(
            @RequestParam(required = false) UUID supplierContactId) {
        return ResponseEntity.ok(ApiResponse.ok(service.listActive(supplierContactId)));
    }

    @GetMapping("/lookup")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> lookupRate(
            @RequestParam UUID supplierContactId,
            @RequestParam UUID itemId) {
        Optional<BigDecimal> rate = service.findActiveRate(supplierContactId, itemId);
        return ResponseEntity.ok(ApiResponse.ok(
                Map.of("hasActiveContract", rate.isPresent(),
                        "unitPrice", rate.<Object>map(b -> b).orElse(""))));
    }

    @PostMapping("/{id}/activate")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<SupplierRateContractResponse>> activate(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.activate(id), "Rate contract activated"));
    }

    @PostMapping("/{id}/expire")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<SupplierRateContractResponse>> expire(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.expire(id), "Rate contract expired"));
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<SupplierRateContractResponse>> cancel(
            @PathVariable UUID id,
            @RequestBody(required = false) Map<String, String> body) {
        String reason = body != null ? body.get("reason") : null;
        return ResponseEntity.ok(ApiResponse.ok(
                service.cancel(id, reason), "Rate contract cancelled"));
    }
}
