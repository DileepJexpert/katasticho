package com.katasticho.erp.hr.controller;

import com.katasticho.erp.attendance.AttendanceRegularization;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.hr.service.AttendanceManagementService;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** HR Attendance management — Core HR module 2: regularization + monthly summary. */
@RestController
@RequestMapping("/api/v1/hr/attendance")
@RequiredArgsConstructor
public class AttendanceManagementController {

    private final AttendanceManagementService service;

    @PostMapping("/regularizations")
    public ResponseEntity<ApiResponse<AttendanceRegularization>> request(@RequestBody Map<String, Object> b) {
        AttendanceRegularization r = service.request(
                LocalDate.parse(b.get("workDate").toString()),
                instant(b.get("punchIn")), instant(b.get("punchOut")),
                (String) b.get("reason"));
        return ResponseEntity.ok(ApiResponse.ok(r, "Regularization requested"));
    }

    @PostMapping("/regularizations/{id}/approve")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<AttendanceRegularization>> approve(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.approve(id), "Regularization approved"));
    }

    @PostMapping("/regularizations/{id}/reject")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<AttendanceRegularization>> reject(
            @PathVariable UUID id, @RequestBody(required = false) Map<String, Object> b) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.reject(id, b != null ? (String) b.get("reason") : null), "Regularization rejected"));
    }

    @GetMapping("/regularizations/me")
    public ResponseEntity<ApiResponse<List<AttendanceRegularization>>> mine() {
        return ResponseEntity.ok(ApiResponse.ok(service.myRegularizations()));
    }

    @GetMapping("/regularizations/pending")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<List<AttendanceRegularization>>> pending() {
        return ResponseEntity.ok(ApiResponse.ok(service.pending()));
    }

    @GetMapping("/summary/me")
    public ResponseEntity<ApiResponse<Map<String, Object>>> mySummary(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate month) {
        return ResponseEntity.ok(ApiResponse.ok(service.monthlySummary(null, month)));
    }

    @GetMapping("/summary/{userId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> userSummary(
            @PathVariable UUID userId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate month) {
        return ResponseEntity.ok(ApiResponse.ok(service.monthlySummary(userId, month)));
    }

    private static Instant instant(Object o) {
        return o != null ? Instant.parse(o.toString()) : null;
    }
}
