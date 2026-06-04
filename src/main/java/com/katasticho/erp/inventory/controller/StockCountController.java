package com.katasticho.erp.inventory.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.dto.PagedResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.inventory.dto.CreateStockCountRequest;
import com.katasticho.erp.inventory.dto.StockCountResponse;
import com.katasticho.erp.inventory.service.StockCountService;
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
@RequestMapping("/api/v1/stock-counts")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.INVENTORY)
public class StockCountController {

    private final StockCountService stockCountService;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<StockCountResponse>> create(
            @Valid @RequestBody CreateStockCountRequest request) {
        StockCountResponse response = stockCountService.create(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(response));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<StockCountResponse>>> list(Pageable pageable) {
        Page<StockCountResponse> page = stockCountService.list(pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<StockCountResponse>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(stockCountService.get(id)));
    }

    @PostMapping("/{id}/post")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<StockCountResponse>> post(@PathVariable UUID id) {
        StockCountResponse response = stockCountService.post(id);
        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> cancel(@PathVariable UUID id) {
        stockCountService.cancel(id);
        return ResponseEntity.ok(ApiResponse.ok(null));
    }
}
