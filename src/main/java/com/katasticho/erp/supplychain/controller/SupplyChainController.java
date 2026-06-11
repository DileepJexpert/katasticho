package com.katasticho.erp.supplychain.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.supplychain.entity.*;
import com.katasticho.erp.supplychain.service.SupplyChainService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/supply-chain")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
public class SupplyChainController {

    private final SupplyChainService service;

    // ── Item-Supplier ──

    @PostMapping("/item-suppliers")
    public ApiResponse<ItemSupplier> addItemSupplier(@RequestBody Map<String, Object> body) {
        return ApiResponse.ok(service.addItemSupplier(
                UUID.fromString((String) body.get("itemId")),
                UUID.fromString((String) body.get("supplierId")),
                body.containsKey("leadTimeDays") ? (Integer) body.get("leadTimeDays") : 7,
                body.containsKey("minOrderQty") ? new BigDecimal(body.get("minOrderQty").toString()) : BigDecimal.ONE,
                body.containsKey("unitPrice") ? new BigDecimal(body.get("unitPrice").toString()) : BigDecimal.ZERO,
                body.containsKey("preferred") ? (Boolean) body.get("preferred") : false,
                (String) body.get("supplierSku")
        ));
    }

    @GetMapping("/item-suppliers/by-item/{itemId}")
    public ApiResponse<List<ItemSupplier>> getItemSuppliers(@PathVariable UUID itemId) {
        return ApiResponse.ok(service.getItemSuppliers(itemId));
    }

    @GetMapping("/item-suppliers/by-supplier/{supplierId}")
    public ApiResponse<List<ItemSupplier>> getSupplierItems(@PathVariable UUID supplierId) {
        return ApiResponse.ok(service.getSupplierItems(supplierId));
    }

    @PostMapping("/item-suppliers/{itemId}/preferred/{supplierId}")
    public ApiResponse<ItemSupplier> setPreferred(@PathVariable UUID itemId, @PathVariable UUID supplierId) {
        return ApiResponse.ok(service.setPreferredSupplier(itemId, supplierId));
    }

    @DeleteMapping("/item-suppliers/{id}")
    public ApiResponse<Void> removeItemSupplier(@PathVariable UUID id) {
        service.removeItemSupplier(id);
        return ApiResponse.ok(null);
    }

    // ── Demand Forecast ──

    @PostMapping("/forecasts/generate")
    public ApiResponse<List<DemandForecast>> generateForecast(
            @RequestParam(defaultValue = "3") int monthsAhead,
            @RequestParam(defaultValue = "6") int historyMonths) {
        return ApiResponse.ok(service.generateForecast(monthsAhead, historyMonths));
    }

    @GetMapping("/forecasts/by-item/{itemId}")
    public ApiResponse<List<DemandForecast>> getForecasts(@PathVariable UUID itemId) {
        return ApiResponse.ok(service.getForecasts(itemId));
    }

    @GetMapping("/forecasts")
    public ApiResponse<List<DemandForecast>> getForecastsInRange(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ApiResponse.ok(service.getForecastsInRange(from, to));
    }

    // ── ABC Classification ──

    @PostMapping("/abc/run")
    public ApiResponse<List<ReorderPolicy>> runAbcClassification() {
        return ApiResponse.ok(service.runAbcClassification());
    }

    @GetMapping("/reorder-policies")
    public ApiResponse<List<ReorderPolicy>> getReorderPolicies() {
        return ApiResponse.ok(service.getReorderPolicies());
    }

    @GetMapping("/abc/{abcClass}")
    public ApiResponse<List<ReorderPolicy>> getByAbcClass(@PathVariable String abcClass) {
        return ApiResponse.ok(service.getByAbcClass(abcClass));
    }

    // ── Safety Stock & EOQ ──

    @PostMapping("/reorder-params/{itemId}")
    public ApiResponse<ReorderPolicy> calculateReorderParams(
            @PathVariable UUID itemId,
            @RequestParam(required = false) UUID warehouseId) {
        return ApiResponse.ok(service.calculateReorderParams(itemId, warehouseId));
    }

    // ── Purchase Requisition ──

    @PostMapping("/requisitions")
    public ApiResponse<PurchaseRequisition> createRequisition(@RequestBody Map<String, Object> body) {
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> lineData = (List<Map<String, Object>>) body.get("lines");
        List<SupplyChainService.RequisitionLineRequest> lines = lineData.stream()
                .map(l -> new SupplyChainService.RequisitionLineRequest(
                        UUID.fromString((String) l.get("itemId")),
                        new BigDecimal(l.get("requiredQty").toString()),
                        new BigDecimal(l.get("estimatedUnitPrice").toString())
                )).toList();

        return ApiResponse.ok(service.createRequisition(
                body.get("supplierId") != null ? UUID.fromString((String) body.get("supplierId")) : null,
                body.get("warehouseId") != null ? UUID.fromString((String) body.get("warehouseId")) : null,
                body.get("requiredByDate") != null ? LocalDate.parse((String) body.get("requiredByDate")) : null,
                (String) body.get("notes"),
                lines
        ));
    }

    @PostMapping("/requisitions/auto")
    public ApiResponse<PurchaseRequisition> autoCreateRequisition() {
        PurchaseRequisition pr = service.autoCreateRequisition();
        return ApiResponse.ok(pr);
    }

    @GetMapping("/requisitions")
    public ApiResponse<Page<PurchaseRequisition>> listRequisitions(
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.ok(service.listRequisitions(status, page, size));
    }

    @GetMapping("/requisitions/{id}")
    public ApiResponse<PurchaseRequisition> getRequisition(@PathVariable UUID id) {
        return ApiResponse.ok(service.getRequisition(id));
    }

    @PostMapping("/requisitions/{id}/submit")
    public ApiResponse<PurchaseRequisition> submitRequisition(@PathVariable UUID id) {
        return ApiResponse.ok(service.submitRequisition(id));
    }

    @PostMapping("/requisitions/{id}/approve")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ApiResponse<PurchaseRequisition> approveRequisition(@PathVariable UUID id) {
        return ApiResponse.ok(service.approveRequisition(id));
    }

    @PostMapping("/requisitions/{id}/reject")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ApiResponse<PurchaseRequisition> rejectRequisition(@PathVariable UUID id) {
        return ApiResponse.ok(service.rejectRequisition(id));
    }

    // ── Return Orders ──

    @PostMapping("/returns")
    public ApiResponse<ReturnOrder> createReturnOrder(@RequestBody Map<String, Object> body) {
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> lineData = (List<Map<String, Object>>) body.get("lines");
        List<SupplyChainService.ReturnLineRequest> lines = lineData.stream()
                .map(l -> new SupplyChainService.ReturnLineRequest(
                        UUID.fromString((String) l.get("itemId")),
                        l.get("batchId") != null ? UUID.fromString((String) l.get("batchId")) : null,
                        new BigDecimal(l.get("quantity").toString()),
                        new BigDecimal(l.get("unitPrice").toString()),
                        (String) l.get("condition"),
                        l.get("restock") == null || (Boolean) l.get("restock")
                )).toList();

        return ApiResponse.ok(service.createReturnOrder(
                (String) body.getOrDefault("returnType", "PURCHASE_RETURN"),
                body.get("contactId") != null ? UUID.fromString((String) body.get("contactId")) : null,
                body.get("warehouseId") != null ? UUID.fromString((String) body.get("warehouseId")) : null,
                (String) body.get("reasonCode"),
                (String) body.get("reasonNotes"),
                lines
        ));
    }

    @GetMapping("/returns")
    public ApiResponse<Page<ReturnOrder>> listReturnOrders(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String returnType,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.ok(service.listReturnOrders(status, returnType, page, size));
    }

    @GetMapping("/returns/{id}")
    public ApiResponse<ReturnOrder> getReturnOrder(@PathVariable UUID id) {
        return ApiResponse.ok(service.getReturnOrder(id));
    }

    @PostMapping("/returns/{id}/approve")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ApiResponse<ReturnOrder> approveReturn(@PathVariable UUID id) {
        return ApiResponse.ok(service.approveReturn(id));
    }

    @PostMapping("/returns/{id}/process")
    public ApiResponse<ReturnOrder> processReturn(@PathVariable UUID id) {
        return ApiResponse.ok(service.processReturn(id));
    }

    @PostMapping("/returns/{id}/cancel")
    public ApiResponse<ReturnOrder> cancelReturn(@PathVariable UUID id) {
        return ApiResponse.ok(service.cancelReturn(id));
    }

    // ── Alerts ──

    @GetMapping("/alerts")
    public ApiResponse<Page<SupplyChainAlert>> listAlerts(
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.ok(service.listAlerts(status, page, size));
    }

    @PostMapping("/alerts/{id}/resolve")
    public ApiResponse<SupplyChainAlert> resolveAlert(@PathVariable UUID id) {
        return ApiResponse.ok(service.resolveAlert(id));
    }

    @PostMapping("/alerts/scan")
    public ApiResponse<List<SupplyChainAlert>> runAlertScan() {
        return ApiResponse.ok(service.runAlertScan());
    }

    // ── Supplier Performance ──

    @GetMapping("/supplier-performance/{supplierId}")
    public ApiResponse<List<SupplierPerformance>> getSupplierScorecard(@PathVariable UUID supplierId) {
        return ApiResponse.ok(service.getSupplierScorecard(supplierId));
    }

    @GetMapping("/supplier-rankings")
    public ApiResponse<List<SupplierPerformance>> getSupplierRankings() {
        return ApiResponse.ok(service.getSupplierRankings());
    }

    @PostMapping("/supplier-performance/{supplierId}/calculate")
    public ApiResponse<SupplierPerformance> calculatePerformance(
            @PathVariable UUID supplierId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ApiResponse.ok(service.calculateSupplierPerformance(supplierId, from, to));
    }

    // ── Analytics ──

    @GetMapping("/analytics/turnover")
    public ApiResponse<List<Map<String, Object>>> getInventoryTurnover(
            @RequestParam(defaultValue = "12") int months) {
        return ApiResponse.ok(service.getInventoryTurnover(months));
    }

    @GetMapping("/dashboard")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ApiResponse<Map<String, Object>> getDashboard() {
        return ApiResponse.ok(service.getSupplyChainDashboard());
    }
}
