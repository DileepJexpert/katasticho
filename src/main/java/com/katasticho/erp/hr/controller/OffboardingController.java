package com.katasticho.erp.hr.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.hr.entity.Offboarding;
import com.katasticho.erp.hr.entity.OffboardingTask;
import com.katasticho.erp.hr.service.OffboardingService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** HR Offboarding — Core HR module 9. */
@RestController
@RequestMapping("/api/v1/hr/offboarding")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN')")
public class OffboardingController {

    private final OffboardingService service;

    @PostMapping
    public ResponseEntity<ApiResponse<Map<String, Object>>> initiate(@RequestBody Map<String, Object> b) {
        Map<String, Object> r = service.initiate(
                UUID.fromString(b.get("employeeUserId").toString()),
                date(b.get("resignationDate")), date(b.get("lastWorkingDay")),
                (String) b.get("reason"));
        return ResponseEntity.ok(ApiResponse.ok(r, "Offboarding initiated"));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<Map<String, Object>>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getOffboarding(id)));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<List<Offboarding>>> list(
            @RequestParam(required = false) String status) {
        return ResponseEntity.ok(ApiResponse.ok(service.list(status)));
    }

    @PostMapping("/tasks/{taskId}/complete")
    public ResponseEntity<ApiResponse<OffboardingTask>> completeTask(@PathVariable UUID taskId) {
        return ResponseEntity.ok(ApiResponse.ok(service.completeTask(taskId), "Task completed"));
    }

    @PostMapping("/{id}/fnf")
    public ResponseEntity<ApiResponse<Offboarding>> settleFnf(
            @PathVariable UUID id, @RequestBody Map<String, Object> b) {
        BigDecimal amount = b.get("amount") != null ? new BigDecimal(b.get("amount").toString()) : null;
        return ResponseEntity.ok(ApiResponse.ok(service.settleFnf(id, amount), "Full & final settled"));
    }

    @PostMapping("/{id}/complete")
    public ResponseEntity<ApiResponse<Offboarding>> complete(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.complete(id), "Offboarding completed"));
    }

    @PostMapping("/{id}/cancel")
    public ResponseEntity<ApiResponse<Offboarding>> cancel(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.cancel(id), "Offboarding cancelled"));
    }

    private static LocalDate date(Object o) {
        return o == null ? null : LocalDate.parse(o.toString());
    }
}
