package com.katasticho.erp.fieldsales.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.fieldsales.dto.BeatCustomerAssignmentRequest;
import com.katasticho.erp.fieldsales.dto.BeatCustomerResponse;
import com.katasticho.erp.fieldsales.dto.RouteSummaryResponse;
import com.katasticho.erp.fieldsales.entity.*;
import com.katasticho.erp.fieldsales.dto.RouteBeatResponse;
import com.katasticho.erp.fieldsales.service.FieldAllowanceService;
import com.katasticho.erp.fieldsales.service.FieldSalesService;
import com.katasticho.erp.fieldsales.service.FieldSampleService;
import com.katasticho.erp.fieldsales.service.FieldTrackingService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;

@RestController
@RequestMapping("/api/v1/field-sales")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.FIELD_SALES)
@PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
public class FieldSalesController {

    private final FieldSalesService service;
    private final FieldTrackingService trackingService;
    private final FieldAllowanceService allowanceService;
    private final FieldSampleService sampleService;

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
        return ResponseEntity.ok(ApiResponse.ok(
                service.createBeat(beat, parseBeatCustomerAssignments(body.get("customers"))),
                "Beat created"));
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
        List<BeatCustomerAssignmentRequest> assignments = body.containsKey("customers")
                ? parseBeatCustomerAssignments(body.get("customers")) : null;
        return ResponseEntity.ok(ApiResponse.ok(
                service.updateBeat(id, beat, assignments), "Beat updated"));
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
    public ResponseEntity<ApiResponse<List<BeatCustomerResponse>>> getBeatCustomers(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getBeatCustomers(id)));
    }

    /** Parses assignment maps while preserving this controller's Map-based API. */
    private List<BeatCustomerAssignmentRequest> parseBeatCustomerAssignments(Object value) {
        if (value == null) {
            return List.of();
        }
        if (!(value instanceof List<?> rawAssignments)) {
            throw new BusinessException(
                    "Beat customers must be a list",
                    "FS_BEAT_ASSIGNMENTS_INVALID", HttpStatus.BAD_REQUEST);
        }

        List<BeatCustomerAssignmentRequest> assignments = new ArrayList<>();
        for (Object rawAssignment : rawAssignments) {
            if (!(rawAssignment instanceof Map<?, ?> assignment)) {
                throw new BusinessException(
                        "Each beat customer must include a contactId",
                        "FS_BEAT_ASSIGNMENTS_INVALID", HttpStatus.BAD_REQUEST);
            }
            Object contactId = assignment.get("contactId");
            if (contactId == null) {
                throw new BusinessException(
                        "Each beat customer must include a contactId",
                        "FS_BEAT_ASSIGNMENTS_INVALID", HttpStatus.BAD_REQUEST);
            }
            Object sequence = assignment.get("visitSequence");
            Object visitFrequency = assignment.get("visitFrequency");
            try {
                assignments.add(new BeatCustomerAssignmentRequest(
                        UUID.fromString(contactId.toString()),
                        sequence instanceof Number number ? number.intValue() : null,
                        visitFrequency != null ? visitFrequency.toString() : null));
            } catch (IllegalArgumentException exception) {
                throw new BusinessException(
                        "Each beat customer must use a valid contactId",
                        "FS_BEAT_ASSIGNMENTS_INVALID", HttpStatus.BAD_REQUEST);
            }
        }
        return assignments;
    }

    // ══════════════════════════════════════════════════════════════
    // Route endpoints
    // ══════════════════════════════════════════════════════════════

    @PostMapping("/routes")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Route>> createRoute(@RequestBody Map<String, Object> body) {
        List<UUID> beatIds = parseRouteBeatIds(body.get("beatIds"));
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
        List<UUID> beatIds = body.containsKey("beatIds")
                ? parseRouteBeatIds(body.get("beatIds"))
                : null;
        return ResponseEntity.ok(ApiResponse.ok(service.updateRoute(id, route, beatIds), "Route updated"));
    }

    @GetMapping("/routes")
    public ResponseEntity<ApiResponse<Page<RouteSummaryResponse>>> listRoutes(Pageable pageable) {
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
    public ResponseEntity<ApiResponse<List<RouteBeatResponse>>> getRouteBeats(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getRouteBeats(id)));
    }

    private List<UUID> parseRouteBeatIds(Object value) {
        if (value == null) {
            return List.of();
        }
        if (!(value instanceof List<?> rawBeatIds)) {
            throw new BusinessException("beatIds must be an array", "FS_ROUTE_INVALID_BEAT_IDS", HttpStatus.BAD_REQUEST);
        }
        if (rawBeatIds.stream().anyMatch(Objects::isNull)) {
            throw new BusinessException("beatIds must contain valid IDs", "FS_ROUTE_INVALID_BEAT_IDS", HttpStatus.BAD_REQUEST);
        }
        try {
            return rawBeatIds.stream()
                    .map(Object::toString)
                    .map(UUID::fromString)
                    .toList();
        } catch (IllegalArgumentException exception) {
            throw new BusinessException("beatIds must contain valid IDs", "FS_ROUTE_INVALID_BEAT_IDS", HttpStatus.BAD_REQUEST);
        }
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
        String rawSoId = (String) body.get("salesOrderId");
        UUID salesOrderId = (rawSoId == null || rawSoId.isBlank()) ? null : UUID.fromString(rawSoId);
        BigDecimal orderValue = new BigDecimal(body.get("orderValue").toString());
        return ResponseEntity.ok(ApiResponse.ok(
                service.recordVisitOrder(id, salesOrderId, orderValue), "Order recorded"));
    }

    @PostMapping("/visits/{id}/record-collection")
    public ResponseEntity<ApiResponse<Map<String, Object>>> recordVisitCollection(
            @PathVariable UUID id,
            @RequestBody Map<String, Object> body) {
        BigDecimal collectionAmount = new BigDecimal(body.get("collectionAmount").toString());
        String paymentMethod = body.get("paymentMethod") != null
                ? body.get("paymentMethod").toString() : "CASH";
        String referenceNumber = body.get("referenceNumber") != null
                ? body.get("referenceNumber").toString() : null;
        return ResponseEntity.ok(ApiResponse.ok(
                service.recordVisitCollectionWithReceipt(id, collectionAmount,
                        paymentMethod, referenceNumber), "Collection recorded"));
    }

    // ══════════════════════════════════════════════════════════════
    // Location tracking endpoints
    // ══════════════════════════════════════════════════════════════

    @PostMapping("/locations/ping")
    public ResponseEntity<ApiResponse<Map<String, Object>>> recordLocationPings(
            @RequestBody Map<String, Object> body) {
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> rawPings = (List<Map<String, Object>>) body.get("pings");
        List<FieldTrackingService.PingRequest> pings = new ArrayList<>();
        if (rawPings != null) {
            for (Map<String, Object> p : rawPings) {
                pings.add(new FieldTrackingService.PingRequest(
                        p.get("latitude") != null ? new BigDecimal(p.get("latitude").toString()) : null,
                        p.get("longitude") != null ? new BigDecimal(p.get("longitude").toString()) : null,
                        p.get("accuracyM") != null ? new BigDecimal(p.get("accuracyM").toString()) : null,
                        p.get("recordedAt") != null ? Instant.parse(p.get("recordedAt").toString()) : null,
                        p.get("routeExecutionId") != null
                                ? UUID.fromString(p.get("routeExecutionId").toString()) : null));
            }
        }
        int saved = trackingService.recordPings(pings).size();
        return ResponseEntity.ok(ApiResponse.ok(Map.of("saved", saved), "Pings recorded"));
    }

    @GetMapping("/locations/live")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getLiveLocations() {
        return ResponseEntity.ok(ApiResponse.ok(trackingService.liveLocations()));
    }

    @GetMapping("/locations/trail/{executionId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getTrail(@PathVariable UUID executionId) {
        return ResponseEntity.ok(ApiResponse.ok(trackingService.trail(executionId)));
    }

    // ══════════════════════════════════════════════════════════════
    // TA/DA allowance endpoints (all verticals)
    // ══════════════════════════════════════════════════════════════

    @GetMapping("/allowance/me")
    public ResponseEntity<ApiResponse<Map<String, Object>>> myAllowance(
            @RequestParam(required = false) LocalDate date) {
        return ResponseEntity.ok(ApiResponse.ok(
                allowanceService.computeAllowance(date != null ? date : LocalDate.now())));
    }

    @PostMapping("/allowance/claim")
    public ResponseEntity<ApiResponse<FieldAllowanceClaim>> claimAllowance(
            @RequestBody(required = false) Map<String, Object> body) {
        LocalDate date = body != null && body.get("date") != null
                ? LocalDate.parse(body.get("date").toString()) : LocalDate.now();
        BigDecimal km = body != null && body.get("km") != null
                ? new BigDecimal(body.get("km").toString()) : null;
        return ResponseEntity.ok(ApiResponse.ok(
                allowanceService.claim(date, km), "Allowance claimed"));
    }

    @GetMapping("/allowance/claims/me")
    public ResponseEntity<ApiResponse<List<FieldAllowanceClaim>>> myAllowanceClaims() {
        return ResponseEntity.ok(ApiResponse.ok(allowanceService.myClaims()));
    }

    // ══════════════════════════════════════════════════════════════
    // Sample / promo stock endpoints (all verticals)
    // ══════════════════════════════════════════════════════════════

    @PostMapping("/samples/issue")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<FieldSampleTxn>> issueSamples(
            @RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(ApiResponse.ok(
                recordSampleTxn("ISSUE", body), "Samples issued"));
    }

    @PostMapping("/samples/return")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<FieldSampleTxn>> returnSamples(
            @RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(ApiResponse.ok(
                recordSampleTxn("RETURN", body), "Samples returned"));
    }

    private FieldSampleTxn recordSampleTxn(String type, Map<String, Object> body) {
        return sampleService.record(type,
                UUID.fromString(body.get("salespersonId").toString()),
                body.get("itemId") != null ? UUID.fromString(body.get("itemId").toString()) : null,
                (String) body.get("productName"),
                Integer.parseInt(body.get("quantity").toString()),
                body.get("date") != null ? LocalDate.parse(body.get("date").toString()) : null,
                (String) body.get("notes"));
    }

    @GetMapping("/samples/balance/me")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> mySampleBalance() {
        return ResponseEntity.ok(ApiResponse.ok(
                sampleService.balance(TenantContext.getCurrentUserId())));
    }

    @GetMapping("/samples/balance/{salespersonId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> sampleBalance(
            @PathVariable UUID salespersonId) {
        return ResponseEntity.ok(ApiResponse.ok(sampleService.balance(salespersonId)));
    }

    @GetMapping("/samples/transactions/{salespersonId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<List<FieldSampleTxn>>> sampleTransactions(
            @PathVariable UUID salespersonId) {
        return ResponseEntity.ok(ApiResponse.ok(sampleService.transactions(salespersonId)));
    }

    // ══════════════════════════════════════════════════════════════
    // Day Close endpoints
    // ══════════════════════════════════════════════════════════════

    @PostMapping("/day-close/initiate/{routeExecutionId}")
    public ResponseEntity<ApiResponse<DayClose>> initiateDayClose(
            @PathVariable UUID routeExecutionId,
            @RequestBody(required = false) Map<String, Object> body) {
        BigDecimal openingCash = body != null && body.get("openingCash") != null
                ? new BigDecimal(body.get("openingCash").toString()) : BigDecimal.ZERO;
        return ResponseEntity.ok(ApiResponse.ok(
                service.initiateDayClose(routeExecutionId, openingCash), "Day close initiated"));
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
