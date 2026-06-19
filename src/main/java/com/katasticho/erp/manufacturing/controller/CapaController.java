package com.katasticho.erp.manufacturing.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.manufacturing.entity.CapaAction;
import com.katasticho.erp.manufacturing.service.CapaService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Tracker #88: CAPA endpoints. OWNER/ADMIN can raise + manage all CAPAs;
 * OPERATOR can manage CAPAs assigned to them; ACCOUNTANT/VIEWER read.
 */
@RestController
@RequestMapping("/api/v1/manufacturing/capa")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.MANUFACTURING)
public class CapaController {

    private final CapaService service;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
    public ResponseEntity<ApiResponse<CapaAction>> raise(@RequestBody Map<String, Object> body) {
        UUID ncrId = optUuid(body, "ncrId");
        UUID assignedTo = optUuid(body, "assignedTo");
        LocalDate dueDate = body.get("dueDate") != null
                ? LocalDate.parse(body.get("dueDate").toString()) : null;
        CapaAction capa = service.raise(
                ncrId,
                (String) body.get("capaType"),
                (String) body.get("title"),
                (String) body.get("description"),
                (String) body.get("proposedAction"),
                assignedTo,
                dueDate,
                (String) body.get("priority"));
        return ResponseEntity.ok(ApiResponse.ok(capa, "CAPA raised"));
    }

    @PostMapping("/{id}/start")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
    public ResponseEntity<ApiResponse<CapaAction>> start(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.start(id), "Started"));
    }

    @PostMapping("/{id}/complete")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
    public ResponseEntity<ApiResponse<CapaAction>> complete(
            @PathVariable UUID id,
            @RequestBody(required = false) Map<String, Object> body) {
        String notes = body == null ? null : (String) body.get("completionNotes");
        return ResponseEntity.ok(ApiResponse.ok(
                service.complete(id, notes), "Completed"));
    }

    @PostMapping("/{id}/verify")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<CapaAction>> verify(
            @PathVariable UUID id,
            @RequestBody(required = false) Map<String, Object> body) {
        String notes = body == null ? null : (String) body.get("effectivenessNotes");
        return ResponseEntity.ok(ApiResponse.ok(
                service.verify(id, notes), "Verified"));
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<CapaAction>> cancel(
            @PathVariable UUID id,
            @RequestBody(required = false) Map<String, Object> body) {
        String reason = body == null ? null : (String) body.get("reason");
        return ResponseEntity.ok(ApiResponse.ok(
                service.cancel(id, reason), "Cancelled"));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<CapaAction>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.get(id)));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<Page<CapaAction>>> list(
            @RequestParam(required = false) String status,
            Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(service.list(status, pageable)));
    }

    @GetMapping("/by-ncr/{ncrId}")
    public ResponseEntity<ApiResponse<List<CapaAction>>> byNcr(@PathVariable UUID ncrId) {
        return ResponseEntity.ok(ApiResponse.ok(service.listByNcr(ncrId)));
    }

    @GetMapping("/me")
    public ResponseEntity<ApiResponse<List<CapaAction>>> mine() {
        return ResponseEntity.ok(ApiResponse.ok(service.myCapas()));
    }

    @GetMapping("/overdue")
    public ResponseEntity<ApiResponse<List<CapaAction>>> overdue() {
        return ResponseEntity.ok(ApiResponse.ok(service.overdue()));
    }

    @GetMapping("/dashboard")
    public ResponseEntity<ApiResponse<Map<String, Object>>> dashboard() {
        return ResponseEntity.ok(ApiResponse.ok(service.dashboard()));
    }

    private UUID optUuid(Map<String, Object> body, String key) {
        Object v = body.get(key);
        return (v == null || v.toString().isBlank()) ? null
                : UUID.fromString(v.toString());
    }
}
