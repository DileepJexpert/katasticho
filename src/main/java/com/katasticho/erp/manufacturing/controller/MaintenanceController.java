package com.katasticho.erp.manufacturing.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.manufacturing.entity.MaintenanceSchedule;
import com.katasticho.erp.manufacturing.entity.MaintenanceWorkOrder;
import com.katasticho.erp.manufacturing.service.MaintenanceService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** Preventive maintenance + breakdown work orders + downtime reporting. */
@RestController
@RequestMapping("/api/v1/manufacturing/maintenance")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.MANUFACTURING)
@PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
public class MaintenanceController {

    private final MaintenanceService service;

    // ── Schedules ──

    @GetMapping("/schedules")
    public ResponseEntity<ApiResponse<List<MaintenanceSchedule>>> listSchedules(
            @RequestParam(required = false) UUID workstationId) {
        List<MaintenanceSchedule> rows = (workstationId != null)
                ? service.listSchedulesForWorkstation(workstationId)
                : service.listSchedules();
        return ResponseEntity.ok(ApiResponse.ok(rows));
    }

    @GetMapping("/schedules/due")
    public ResponseEntity<ApiResponse<List<MaintenanceSchedule>>> listDueSchedules(
            @RequestParam(required = false) LocalDate cutoff) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.listDueSchedules(cutoff != null ? cutoff : LocalDate.now())));
    }

    @GetMapping("/schedules/{id}")
    public ResponseEntity<ApiResponse<MaintenanceSchedule>> getSchedule(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getSchedule(id)));
    }

    @PostMapping("/schedules")
    public ResponseEntity<ApiResponse<MaintenanceSchedule>> createSchedule(
            @RequestBody MaintenanceSchedule body) {
        return ResponseEntity.ok(ApiResponse.ok(service.createSchedule(body), "Schedule created"));
    }

    @PutMapping("/schedules/{id}")
    public ResponseEntity<ApiResponse<MaintenanceSchedule>> updateSchedule(
            @PathVariable UUID id, @RequestBody MaintenanceSchedule body) {
        return ResponseEntity.ok(ApiResponse.ok(service.updateSchedule(id, body), "Schedule updated"));
    }

    @DeleteMapping("/schedules/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteSchedule(@PathVariable UUID id) {
        service.deleteSchedule(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Schedule removed"));
    }

    @PostMapping("/schedules/generate-due")
    public ResponseEntity<ApiResponse<List<MaintenanceWorkOrder>>> generateDue(
            @RequestParam(required = false) LocalDate asOf) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.generateWorkOrdersForDueSchedules(asOf),
                "Maintenance work orders generated"));
    }

    // ── Work orders ──

    @GetMapping("/work-orders")
    public ResponseEntity<ApiResponse<List<MaintenanceWorkOrder>>> listWorkOrders(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) UUID workstationId) {
        List<MaintenanceWorkOrder> rows;
        if (workstationId != null) {
            rows = service.listWorkOrdersForWorkstation(workstationId);
        } else if (status != null) {
            rows = service.listWorkOrdersByStatus(status);
        } else {
            rows = service.listWorkOrders();
        }
        return ResponseEntity.ok(ApiResponse.ok(rows));
    }

    @GetMapping("/work-orders/{id}")
    public ResponseEntity<ApiResponse<MaintenanceWorkOrder>> getWorkOrder(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getWorkOrder(id)));
    }

    @PostMapping("/work-orders")
    public ResponseEntity<ApiResponse<MaintenanceWorkOrder>> createWorkOrder(
            @RequestBody MaintenanceWorkOrder body) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.createWorkOrder(body), "Maintenance work order created"));
    }

    @PostMapping("/work-orders/{id}/start")
    public ResponseEntity<ApiResponse<MaintenanceWorkOrder>> startWorkOrder(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.startWorkOrder(id), "Started"));
    }

    @PostMapping("/work-orders/{id}/complete")
    public ResponseEntity<ApiResponse<MaintenanceWorkOrder>> completeWorkOrder(
            @PathVariable UUID id, @RequestBody(required = false) Map<String, Object> body) {
        String notes = body != null ? (String) body.get("notes") : null;
        BigDecimal cost = null;
        if (body != null && body.get("cost") != null) {
            cost = new BigDecimal(body.get("cost").toString());
        }
        return ResponseEntity.ok(ApiResponse.ok(
                service.completeWorkOrder(id, notes, cost), "Completed"));
    }

    @PostMapping("/work-orders/{id}/cancel")
    public ResponseEntity<ApiResponse<MaintenanceWorkOrder>> cancelWorkOrder(
            @PathVariable UUID id, @RequestBody(required = false) Map<String, Object> body) {
        String reason = body != null ? (String) body.get("reason") : null;
        return ResponseEntity.ok(ApiResponse.ok(service.cancelWorkOrder(id, reason), "Cancelled"));
    }

    // ── Reports ──

    @GetMapping("/reports/downtime")
    public ResponseEntity<ApiResponse<Map<String, Object>>> downtimeReport(
            @RequestParam LocalDate from, @RequestParam LocalDate to) {
        return ResponseEntity.ok(ApiResponse.ok(service.downtimeReport(from, to)));
    }
}
