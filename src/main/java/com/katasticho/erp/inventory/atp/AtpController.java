package com.katasticho.erp.inventory.atp;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Available-to-Promise REST surface for the SO capture screen.
 *
 * <p>Read-only — every role that touches an SO needs to see the honest answer.
 * Module-gated on {@code INVENTORY} because the underlying balance + open-PO
 * data only exists when inventory is on.
 */
@RestController
@RequestMapping("/api/v1/inventory/atp")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.INVENTORY)
public class AtpController {

    private final AtpService atpService;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<AtpResponse>> compute(
            @RequestParam UUID itemId,
            @RequestParam UUID warehouseId,
            @RequestParam(name = "qty", defaultValue = "0") BigDecimal qty) {
        return ResponseEntity.ok(ApiResponse.ok(atpService.compute(itemId, warehouseId, qty)));
    }
}
