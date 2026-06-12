package com.katasticho.erp.fieldsales.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.fieldsales.entity.*;
import com.katasticho.erp.fieldsales.service.FieldSalesService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;

@RestController
@RequestMapping("/api/v1/field-sales")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.FIELD_SALES)
@PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
public class FieldSalesController {

    private final FieldSalesService service;

    // ══════════════════════════════════════════════════════════════
    // Beat endpoints
    // ══════════════════════════════════════════════════════════════

    @PostMapping("/beats")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Beat>> createBeat(@RequestBody Map<String, Object> body) {
        Beat beat = Beat.builder()
                .code((String) body.get("code"))
                .name((String) body.get("name"))
                .area((String) body.get("area"))
                .city((String) body.get("city"))
                .state((String) body.get("state"))
                .description((String) body.get("description"))
                .build();
        return ResponseEntity.ok(ApiResponse.ok(service.createBeat(beat), "Beat created"));
    }

    @PutMapping("/beats/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Beat>> updateBeat(
            @PathVariable UUID id,
            @RequestBody Map<String, Object> body) {
        Beat beat = Beat.builder()
                .code((String) body.get("code"))
                .name((String) body.get("name"))
                .area((String) body.get("area"))
                .city((String) body.get("city"))
                .state((String) body.get("state"))
                .description((String) body.get("description"))
                .build();
        return ResponseEntity.ok(ApiResponse.ok(service.updateBeat(id, beat), "Beat updated"));
    }

    @GetMapping("/beats")
    public ResponseEntity<ApiResponse<Page<Beat>>> listBeats(Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(service.listBeats(pageable)));
    }

    @GetMapping("/beats/{id}")
    public ResponseEntity<ApiResponse<Beat>> getBeat(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getBeat(id)));
    }

    @DeleteMapping("/beats/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Void>> deleteBeat(@PathVariable UUID id) {
        service.deleteBeat(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Beat deleted"));
    }

    @PostMapping("/beats/{id}/customers")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<BeatCustomer>> addCustomerToBeat(
            @PathVariable UUID id,
            @RequestBody Map<String, Object> body) {
        UUID contactId = UUID.fromString((String) body.get("contactId"));
        Integer visitSequence = body.get("visitSequence") != null
                ? ((Number) body.get("visitSequence")).intValue() : null;
        String visitFrequency = (String) body.get("visitFrequency");
        return ResponseEntity.ok(ApiResponse.ok(
                service.addCustomerToBeat(id, contactId, visitSequence, visitFrequency),
                "Customer added to beat"));
    }

    @DeleteMapping("/beats/{beatId}/customers/{contactId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Void>> removeCustomerFromBeat(
            @PathVariable UUID beatId,
            @PathVariable UUID contactId) {
        service.removeCustomerFromBeat(beatId, contactId);
        return ResponseEntity.ok(ApiResponse.ok(null, "Customer removed from beat"));
    }

    @GetMapping("/beats/{id}/customers")
    public ResponseEntity<ApiResponse<List<BeatCustomer>>> getBeatCustomers(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getBeatCustomers(id)));
    }

    // ══════════════════════════════════════════════════════════════
    // Route endpoints
    // ══════════════════════════════════════════════════════════════

    @SuppressWarnings("unchecked")
    @PostMapping("/routes")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Route>> createRoute(@RequestBody Map<String, Object> body) {
        List<String> beatIdStrings = (List<String>) body.get("beatIds");
        List<UUID> beatIds = beatIdStrings != null
                ? beatIdStrings.stream().map(UUID::fromString).toList()
                : List.of();
        Route route = Route.builder()
                .code((String) body.get("code"))
                .name((String) body.get("name"))
                .dayOfWeek((String) body.get("dayOfWeek"))
                .frequency((String) body.get("frequency"))
                .warehouseId(body.get("warehouseId") != null
                        ? UUID.fromString((String) body.get("warehouseId")) : null)
                .build();
        return ResponseEntity.ok(ApiResponse.ok(service.createRoute(route, beatIds), "Route created"));
    }

    @PutMapping("/routes/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Route>> updateRoute(
            @PathVariable UUID id,
            @RequestBody Map<String, Object> body) {
        Route route = Route.builder()
                .code((String) body.get("code"))
                .name((String) body.get("name"))
                .dayOfWeek((String) body.get("dayOfWeek"))
                .frequency((String) body.get("frequency"))
                .warehouseId(body.get("warehouseId") != null
                        ? UUID.fromString((String) body.get("warehouseId")) : null)
                .build();
        return ResponseEntity.ok(ApiResponse.ok(service.updateRoute(id, route), "Route updated"));
    }

    @GetMapping("/routes")
    public ResponseEntity<ApiResponse<Page<Route>>> listRoutes(Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(service.listRoutes(pageable)));
    }

    @GetMapping("/routes/{id}")
    public ResponseEntity<ApiResponse<Route>> getRoute(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getRoute(id)));
    }

    @DeleteMapping("/routes/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Void>> deleteRoute(@PathVariable UUID id) {
        service.deleteRoute(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Route deleted"));
    }

    @GetMapping("/routes/{id}/beats")
    public ResponseEntity<ApiResponse<List<RouteBeat>>> getRouteBeats(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getRouteBeats(id)));
    }

    // ══════════════════════════════════════════════════════════════
    // Van endpoints
    // ══════════════════════════════════════════════════════════════

    @PostMapping("/vans")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Van>> createVan(@RequestBody Map<String, Object> body) {
        Van van = Van.builder()
                .code((String) body.get("code"))
                .vehicleNumber((String) body.get("vehicleNumber"))
                .name((String) body.get("name"))
                .vehicleType((String) body.get("vehicleType"))
                .sourceWarehouseId(body.get("sourceWarehouseId") != null
                        ? UUID.fromString((String) body.get("sourceWarehouseId")) : null)
                .capacityWeightKg(body.get("capacityWeightKg") != null
                        ? new BigDecimal(body.get("capacityWeightKg").toString()) : null)
                .capacityVolumeLitre(body.get("capacityVolumeLitre") != null
                        ? new BigDecimal(body.get("capacityVolumeLitre").toString()) : null)
                .build();
        return ResponseEntity.ok(ApiResponse.ok(service.createVan(van), "Van created"));
    }

    @PutMapping("/vans/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Van>> updateVan(
            @PathVariable UUID id,
            @RequestBody Map<String, Object> body) {
        Van van = Van.builder()
                .code((String) body.get("code"))
                .vehicleNumber((String) body.get("vehicleNumber"))
                .name((String) body.get("name"))
                .vehicleType((String) body.get("vehicleType"))
                .sourceWarehouseId(body.get("sourceWarehouseId") != null
                        ? UUID.fromString((String) body.get("sourceWarehouseId")) : null)
                .capacityWeightKg(body.get("capacityWeightKg") != null
                        ? new BigDecimal(body.get("capacityWeightKg").toString()) : null)
                .capacityVolumeLitre(body.get("capacityVolumeLitre") != null
                        ? new BigDecimal(body.get("capacityVolumeLitre").toString()) : null)
                .build();
        return ResponseEntity.ok(ApiResponse.ok(service.updateVan(id, van), "Van updated"));
    }

    @GetMapping("/vans")
    public ResponseEntity<ApiResponse<Page<Van>>> listVans(Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(service.listVans(pageable)));
    }

    @GetMapping("/vans/{id}")
    public ResponseEntity<ApiResponse<Van>> getVan(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getVan(id)));
    }

    @DeleteMapping("/vans/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Void>> deleteVan(@PathVariable UUID id) {
        service.deleteVan(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Van deleted"));
    }

    @GetMapping("/vans/{id}/stock")
    public ResponseEntity<ApiResponse<List<VanStockBalance>>> getVanStock(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getVanStock(id)));
    }

    // ══════════════════════════════════════════════════════════════
    // Assignment endpoints
    // ══════════════════════════════════════════════════════════════

    @PostMapping("/assignments")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<FieldSalesAssignment>> createAssignment(
            @RequestBody Map<String, Object> body) {
        FieldSalesAssignment assignment = FieldSalesAssignment.builder()
                .salespersonId(UUID.fromString((String) body.get("salespersonId")))
                .routeId(body.get("routeId") != null
                        ? UUID.fromString((String) body.get("routeId")) : null)
                .vanId(body.get("vanId") != null
                        ? UUID.fromString((String) body.get("vanId")) : null)
                .territory((String) body.get("territory"))
                .effectiveFrom(LocalDate.parse((String) body.get("effectiveFrom")))
                .effectiveTo(body.get("effectiveTo") != null
                        ? LocalDate.parse((String) body.get("effectiveTo")) : null)
                .build();
        return ResponseEntity.ok(ApiResponse.ok(
                service.createAssignment(assignment), "Assignment created"));
    }

    @GetMapping("/assignments")
    public ResponseEntity<ApiResponse<List<FieldSalesAssignment>>> getAllAssignments() {
        return ResponseEntity.ok(ApiResponse.ok(service.getAllAssignments()));
    }

    @GetMapping("/assignments/salesperson/{id}")
    public ResponseEntity<ApiResponse<List<FieldSalesAssignment>>> getAssignmentsForSalesperson(
            @PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getAssignmentsForSalesperson(id)));
    }

    @GetMapping("/assignments/me")
    public ResponseEntity<ApiResponse<List<FieldSalesAssignment>>> getMyAssignments() {
        UUID userId = TenantContext.getCurrentUserId();
        return ResponseEntity.ok(ApiResponse.ok(service.getAssignmentsForSalesperson(userId)));
    }

    // ══════════════════════════════════════════════════════════════
    // Van Stock Transfer endpoints
    // ══════════════════════════════════════════════════════════════

    // OPERATOR may request a load (creates DRAFT only — stock moves at confirm, which stays OWNER/ADMIN)
    @SuppressWarnings("unchecked")
    @PostMapping("/van-transfers/load")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
    public ResponseEntity<ApiResponse<VanStockTransfer>> createVanLoad(
            @RequestBody Map<String, Object> body) {
        UUID vanId = UUID.fromString((String) body.get("vanId"));
        UUID warehouseId = UUID.fromString((String) body.get("warehouseId"));
        List<Map<String, Object>> lines = (List<Map<String, Object>>) body.get("lines");
        return ResponseEntity.ok(ApiResponse.ok(
                service.createVanLoad(vanId, warehouseId, lines), "Van load created"));
    }

    @PostMapping("/van-transfers/{id}/confirm-load")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<VanStockTransfer>> confirmVanLoad(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.confirmVanLoad(id), "Van load confirmed"));
    }

    // OPERATOR may initiate a return (creates DRAFT only — stock moves at confirm, which stays OWNER/ADMIN)
    @SuppressWarnings("unchecked")
    @PostMapping("/van-transfers/return")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
    public ResponseEntity<ApiResponse<VanStockTransfer>> createVanReturn(
            @RequestBody Map<String, Object> body) {
        UUID vanId = UUID.fromString((String) body.get("vanId"));
        UUID warehouseId = UUID.fromString((String) body.get("warehouseId"));
        UUID routeExecutionId = body.get("routeExecutionId") != null
                ? UUID.fromString((String) body.get("routeExecutionId")) : null;
        List<Map<String, Object>> lines = (List<Map<String, Object>>) body.get("lines");
        return ResponseEntity.ok(ApiResponse.ok(
                service.createVanReturn(vanId, warehouseId, routeExecutionId, lines),
                "Van return created"));
    }

    @PostMapping("/van-transfers/{id}/confirm-return")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<VanStockTransfer>> confirmVanReturn(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.confirmVanReturn(id), "Van return confirmed"));
    }

    @GetMapping("/van-transfers/van/{vanId}")
    public ResponseEntity<ApiResponse<Page<VanStockTransfer>>> listVanTransfers(
            @PathVariable UUID vanId,
            Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(service.listVanTransfers(vanId, pageable)));
    }

    @GetMapping("/van-transfers/{id}/lines")
    public ResponseEntity<ApiResponse<List<VanStockTransferLine>>> getTransferLines(
            @PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getTransferLines(id)));
    }

    // ══════════════════════════════════════════════════════════════
    // Route Execution endpoints
    // ══════════════════════════════════════════════════════════════

    @PostMapping("/executions")
    public ResponseEntity<ApiResponse<RouteExecution>> startExecution(
            @RequestBody Map<String, Object> body) {
        UUID routeId = UUID.fromString((String) body.get("routeId"));
        UUID salespersonId = UUID.fromString((String) body.get("salespersonId"));
        UUID vanId = body.get("vanId") != null
                ? UUID.fromString((String) body.get("vanId")) : null;
        LocalDate executionDate = LocalDate.parse((String) body.get("executionDate"));
        return ResponseEntity.ok(ApiResponse.ok(
                service.startExecution(routeId, salespersonId, vanId, executionDate),
                "Route execution created"));
    }

    @GetMapping("/executions")
    public ResponseEntity<ApiResponse<Page<RouteExecution>>> listExecutions(Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(service.listExecutions(pageable)));
    }

    @GetMapping("/executions/{id}")
    public ResponseEntity<ApiResponse<RouteExecution>> getExecution(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getExecution(id)));
    }

    @GetMapping("/executions/date/{date}")
    public ResponseEntity<ApiResponse<List<RouteExecution>>> getExecutionsByDate(
            @PathVariable LocalDate date) {
        return ResponseEntity.ok(ApiResponse.ok(service.getExecutionsByDate(date)));
    }

    @GetMapping("/executions/me/today")
    public ResponseEntity<ApiResponse<List<RouteExecution>>> getMyTodayExecutions() {
        UUID userId = TenantContext.getCurrentUserId();
        return ResponseEntity.ok(ApiResponse.ok(
                service.getExecutionsForSalesperson(userId, LocalDate.now())));
    }

    @PostMapping("/executions/{id}/start")
    public ResponseEntity<ApiResponse<RouteExecution>> startRoute(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.startRoute(id), "Route started"));
    }

    @PostMapping("/executions/{id}/complete")
    public ResponseEntity<ApiResponse<RouteExecution>> completeRoute(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.completeRoute(id), "Route completed"));
    }

    // ══════════════════════════════════════════════════════════════
    // Field Visit endpoints
    // ══════════════════════════════════════════════════════════════

    @GetMapping("/executions/{executionId}/visits")
    public ResponseEntity<ApiResponse<List<FieldVisit>>> getVisits(
            @PathVariable UUID executionId) {
        return ResponseEntity.ok(ApiResponse.ok(service.getVisits(executionId)));
    }

    @PostMapping("/visits/{id}/check-in")
    public ResponseEntity<ApiResponse<FieldVisit>> checkIn(
            @PathVariable UUID id,
            @RequestBody Map<String, Object> body) {
        BigDecimal latitude = body.get("latitude") != null
                ? new BigDecimal(body.get("latitude").toString()) : BigDecimal.ZERO;
        BigDecimal longitude = body.get("longitude") != null
                ? new BigDecimal(body.get("longitude").toString()) : BigDecimal.ZERO;
        return ResponseEntity.ok(ApiResponse.ok(
                service.checkIn(id, latitude, longitude), "Checked in"));
    }

    @PostMapping("/visits/{id}/check-out")
    public ResponseEntity<ApiResponse<FieldVisit>> checkOut(
            @PathVariable UUID id,
            @RequestBody Map<String, Object> body) {
        BigDecimal latitude = body.get("latitude") != null
                ? new BigDecimal(body.get("latitude").toString()) : BigDecimal.ZERO;
        BigDecimal longitude = body.get("longitude") != null
                ? new BigDecimal(body.get("longitude").toString()) : BigDecimal.ZERO;
        String notes = body.get("notes") != null ? body.get("notes").toString() : null;
        return ResponseEntity.ok(ApiResponse.ok(
                service.checkOut(id, latitude, longitude, notes), "Checked out"));
    }

    @PostMapping("/visits/{id}/skip")
    public ResponseEntity<ApiResponse<FieldVisit>> skipVisit(
            @PathVariable UUID id,
            @RequestBody Map<String, Object> body) {
        String skipReason = (String) body.get("skipReason");
        return ResponseEntity.ok(ApiResponse.ok(
                service.skipVisit(id, skipReason), "Visit skipped"));
    }

    @PostMapping("/visits/{id}/record-order")
    public ResponseEntity<ApiResponse<FieldVisit>> recordVisitOrder(
            @PathVariable UUID id,
            @RequestBody Map<String, Object> body) {
        UUID salesOrderId = UUID.fromString((String) body.get("salesOrderId"));
        BigDecimal orderValue = new BigDecimal(body.get("orderValue").toString());
        return ResponseEntity.ok(ApiResponse.ok(
                service.recordVisitOrder(id, salesOrderId, orderValue), "Order recorded"));
    }

    @PostMapping("/visits/{id}/record-collection")
    public ResponseEntity<ApiResponse<FieldVisit>> recordVisitCollection(
            @PathVariable UUID id,
            @RequestBody Map<String, Object> body) {
        BigDecimal collectionAmount = new BigDecimal(body.get("collectionAmount").toString());
        return ResponseEntity.ok(ApiResponse.ok(
                service.recordVisitCollection(id, collectionAmount), "Collection recorded"));
    }

    // ══════════════════════════════════════════════════════════════
    // Day Close endpoints
    // ══════════════════════════════════════════════════════════════

    @PostMapping("/day-close/initiate/{routeExecutionId}")
    public ResponseEntity<ApiResponse<DayClose>> initiateDayClose(
            @PathVariable UUID routeExecutionId) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.initiateDayClose(routeExecutionId), "Day close initiated"));
    }

    @GetMapping("/day-close/{id}")
    public ResponseEntity<ApiResponse<DayClose>> getDayClose(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getDayClose(id)));
    }

    @PostMapping("/day-close/{id}/submit")
    public ResponseEntity<ApiResponse<DayClose>> submitDayClose(
            @PathVariable UUID id,
            @RequestBody Map<String, Object> body) {
        BigDecimal closingCash = body.get("closingCash") != null
                ? new BigDecimal(body.get("closingCash").toString()) : null;
        BigDecimal cashDeposited = body.get("cashDeposited") != null
                ? new BigDecimal(body.get("cashDeposited").toString()) : null;
        String notes = (String) body.get("notes");
        return ResponseEntity.ok(ApiResponse.ok(
                service.submitDayClose(id, closingCash, cashDeposited, notes),
                "Day close submitted"));
    }

    @PostMapping("/day-close/{id}/approve")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<DayClose>> approveDayClose(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.approveDayClose(id), "Day close approved"));
    }

    @PostMapping("/day-close/{id}/reject")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<DayClose>> rejectDayClose(
            @PathVariable UUID id,
            @RequestBody Map<String, Object> body) {
        String reason = (String) body.get("reason");
        return ResponseEntity.ok(ApiResponse.ok(
                service.rejectDayClose(id, reason), "Day close rejected"));
    }

    // ══════════════════════════════════════════════════════════════
    // Salesman Target endpoints
    // ══════════════════════════════════════════════════════════════

    @PostMapping("/targets")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<SalesmanTarget>> createTarget(
            @RequestBody Map<String, Object> body) {
        SalesmanTarget target = SalesmanTarget.builder()
                .salespersonId(UUID.fromString((String) body.get("salespersonId")))
                .periodType((String) body.get("periodType"))
                .periodStart(LocalDate.parse((String) body.get("periodStart")))
                .periodEnd(LocalDate.parse((String) body.get("periodEnd")))
                .targetType((String) body.get("targetType"))
                .targetValue(new BigDecimal(body.get("targetValue").toString()))
                .incentiveRate(body.get("incentiveRate") != null
                        ? new BigDecimal(body.get("incentiveRate").toString()) : BigDecimal.ZERO)
                .build();
        return ResponseEntity.ok(ApiResponse.ok(
                service.createTarget(target), "Target created"));
    }

    @GetMapping("/targets")
    public ResponseEntity<ApiResponse<Page<SalesmanTarget>>> listAllTargets(Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(service.listAllTargets(pageable)));
    }

    @GetMapping("/targets/salesperson/{id}")
    public ResponseEntity<ApiResponse<List<SalesmanTarget>>> getTargets(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getTargets(id)));
    }

    @GetMapping("/targets/me")
    public ResponseEntity<ApiResponse<List<SalesmanTarget>>> getMyTargets() {
        UUID userId = TenantContext.getCurrentUserId();
        return ResponseEntity.ok(ApiResponse.ok(service.getTargets(userId)));
    }

    @PutMapping("/targets/{id}/achievement")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<SalesmanTarget>> updateAchievement(
            @PathVariable UUID id,
            @RequestBody Map<String, Object> body) {
        BigDecimal achievedValue = new BigDecimal(body.get("achievedValue").toString());
        return ResponseEntity.ok(ApiResponse.ok(
                service.updateAchievement(id, achievedValue), "Achievement updated"));
    }

    // ══════════════════════════════════════════════════════════════
    // Dashboard endpoint
    // ══════════════════════════════════════════════════════════════

    @GetMapping("/dashboard")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getSecondaryDashboard(
            @RequestParam LocalDate from,
            @RequestParam LocalDate to) {
        return ResponseEntity.ok(ApiResponse.ok(service.getSecondaryDashboard(from, to)));
    }
}
