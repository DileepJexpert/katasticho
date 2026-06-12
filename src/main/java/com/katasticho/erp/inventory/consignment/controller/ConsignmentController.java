package com.katasticho.erp.inventory.consignment.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.inventory.consignment.entity.ConsignmentSettlement;
import com.katasticho.erp.inventory.consignment.entity.ConsignmentStock;
import com.katasticho.erp.inventory.consignment.service.ConsignmentService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/inventory/consignment")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
public class ConsignmentController {

    private final ConsignmentService service;

    /** Receive consignment stock from a supplier. */
    @PostMapping("/receive")
    public ApiResponse<ConsignmentStock> receiveConsignment(@RequestBody Map<String, Object> body) {
        UUID itemId      = UUID.fromString((String) body.get("itemId"));
        UUID warehouseId = UUID.fromString((String) body.get("warehouseId"));
        UUID supplierId  = UUID.fromString((String) body.get("supplierId"));
        BigDecimal qty   = new BigDecimal(body.get("quantity").toString());
        BigDecimal cost  = new BigDecimal(body.get("unitCost").toString());
        LocalDate date   = body.containsKey("consignmentDate")
                ? LocalDate.parse((String) body.get("consignmentDate")) : null;
        String ref       = (String) body.get("agreementRef");

        return ApiResponse.ok(service.receiveConsignment(itemId, warehouseId, supplierId, qty, cost, date, ref));
    }

    /** Record a sale of consignment goods. */
    @PostMapping("/record-sale")
    public ApiResponse<ConsignmentSettlement> recordSale(@RequestBody Map<String, Object> body) {
        UUID consignmentStockId = UUID.fromString((String) body.get("consignmentStockId"));
        BigDecimal qtySold      = new BigDecimal(body.get("quantitySold").toString());
        return ApiResponse.ok(service.recordSale(consignmentStockId, qtySold));
    }

    /** Settle a consignment (mark payable to supplier). */
    @PostMapping("/{id}/settle")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ApiResponse<ConsignmentSettlement> settle(@PathVariable UUID id) {
        return ApiResponse.ok(service.settleConsignment(id));
    }

    /** List all consignment stock for the current org. */
    @GetMapping("/stock")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ApiResponse<List<ConsignmentStock>> getStock() {
        return ApiResponse.ok(service.getConsignmentStock());
    }

    /** List unsettled (DRAFT) sale settlements for a specific supplier. */
    @GetMapping("/unsettled/{supplierId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ApiResponse<List<ConsignmentSettlement>> getUnsettled(@PathVariable UUID supplierId) {
        return ApiResponse.ok(service.getUnsettledSales(supplierId));
    }
}
