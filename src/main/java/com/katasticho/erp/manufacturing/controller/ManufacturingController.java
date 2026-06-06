package com.katasticho.erp.manufacturing.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.manufacturing.entity.WorkOrder;
import com.katasticho.erp.manufacturing.service.ManufacturingService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/manufacturing")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.MANUFACTURING)
@PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
public class ManufacturingController {

    private final ManufacturingService service;

    @PostMapping("/work-orders")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<WorkOrder>> createWorkOrder(@RequestBody Map<String, Object> body) {
        UUID finishedGoodId = UUID.fromString((String) body.get("finishedGoodId"));
        UUID warehouseId = UUID.fromString((String) body.get("warehouseId"));
        BigDecimal qty = new BigDecimal(body.get("quantityToProduce").toString());
        LocalDate plannedStart = body.get("plannedStartDate") != null
                ? LocalDate.parse((String) body.get("plannedStartDate")) : null;
        LocalDate plannedEnd = body.get("plannedEndDate") != null
                ? LocalDate.parse((String) body.get("plannedEndDate")) : null;
        BigDecimal laborCost = body.get("directLaborCost") != null
                ? new BigDecimal(body.get("directLaborCost").toString()) : null;
        BigDecimal overhead = body.get("overheadCost") != null
                ? new BigDecimal(body.get("overheadCost").toString()) : null;
        String notes = (String) body.get("notes");

        return ResponseEntity.ok(ApiResponse.ok(
                service.createWorkOrder(finishedGoodId, warehouseId, qty,
                        plannedStart, plannedEnd, laborCost, overhead, notes),
                "Work order created"));
    }

    @GetMapping("/work-orders")
    public ResponseEntity<ApiResponse<Page<WorkOrder>>> listWorkOrders(
            @RequestParam(required = false) String status,
            Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(service.listWorkOrders(status, pageable)));
    }

    @GetMapping("/work-orders/{id}")
    public ResponseEntity<ApiResponse<WorkOrder>> getWorkOrder(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getWorkOrder(id)));
    }

    @PostMapping("/work-orders/{id}/issue")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<WorkOrder>> issueToProduction(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.issueToProduction(id), "Issued to production"));
    }

    @PostMapping("/work-orders/{id}/receive")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<WorkOrder>> receiveFinishedGoods(
            @PathVariable UUID id,
            @RequestBody Map<String, Object> body) {
        BigDecimal qty = new BigDecimal(body.get("quantityReceived").toString());
        return ResponseEntity.ok(ApiResponse.ok(
                service.receiveFinishedGoods(id, qty), "Finished goods received"));
    }

    @PutMapping("/work-orders/{id}/costs")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<WorkOrder>> updateCosts(
            @PathVariable UUID id,
            @RequestBody Map<String, Object> body) {
        BigDecimal laborCost = body.get("directLaborCost") != null
                ? new BigDecimal(body.get("directLaborCost").toString()) : null;
        BigDecimal overhead = body.get("overheadCost") != null
                ? new BigDecimal(body.get("overheadCost").toString()) : null;
        return ResponseEntity.ok(ApiResponse.ok(
                service.updateCosts(id, laborCost, overhead), "Costs updated"));
    }

    @PostMapping("/work-orders/{id}/cancel")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<WorkOrder>> cancelWorkOrder(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.cancelWorkOrder(id), "Work order cancelled"));
    }
}
