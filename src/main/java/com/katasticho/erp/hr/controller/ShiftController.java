package com.katasticho.erp.hr.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.hr.entity.Shift;
import com.katasticho.erp.hr.entity.ShiftAssignment;
import com.katasticho.erp.hr.service.ShiftManagementService;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** HR Shift management — Core HR module 3. */
@RestController
@RequestMapping("/api/v1/hr/shifts")
@RequiredArgsConstructor
public class ShiftController {

    private final ShiftManagementService service;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Shift>> upsert(@RequestBody Map<String, Object> b) {
        Shift s = service.upsertShift(
                b.get("id") != null ? UUID.fromString(b.get("id").toString()) : null,
                (String) b.get("code"), (String) b.get("name"),
                LocalTime.parse(b.get("startTime").toString()),
                LocalTime.parse(b.get("endTime").toString()),
                (String) b.get("weeklyOffs"),
                b.get("active") == null || Boolean.parseBoolean(b.get("active").toString()));
        return ResponseEntity.ok(ApiResponse.ok(s, "Shift saved"));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<List<Shift>>> list(
            @RequestParam(defaultValue = "false") boolean activeOnly) {
        return ResponseEntity.ok(ApiResponse.ok(service.listShifts(activeOnly)));
    }

    @PostMapping("/assignments")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<ShiftAssignment>> assign(@RequestBody Map<String, Object> b) {
        ShiftAssignment a = service.assignShift(
                UUID.fromString(b.get("userId").toString()),
                UUID.fromString(b.get("shiftId").toString()),
                LocalDate.parse(b.get("effectiveFrom").toString()),
                b.get("effectiveTo") != null ? LocalDate.parse(b.get("effectiveTo").toString()) : null);
        return ResponseEntity.ok(ApiResponse.ok(a, "Shift assigned"));
    }

    @GetMapping("/assignments")
    public ResponseEntity<ApiResponse<List<ShiftAssignment>>> assignments(@RequestParam UUID userId) {
        return ResponseEntity.ok(ApiResponse.ok(service.listAssignments(userId)));
    }

    @GetMapping("/assignments/on")
    public ResponseEntity<ApiResponse<Shift>> shiftOn(
            @RequestParam UUID userId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return ResponseEntity.ok(ApiResponse.ok(service.shiftOn(userId, date).orElse(null)));
    }
}
