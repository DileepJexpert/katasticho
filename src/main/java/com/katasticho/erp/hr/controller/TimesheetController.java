package com.katasticho.erp.hr.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.hr.entity.TimesheetEntry;
import com.katasticho.erp.hr.service.TimesheetService;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** HR Timesheets — Core HR module 4. */
@RestController
@RequestMapping("/api/v1/hr/timesheets")
@RequiredArgsConstructor
public class TimesheetController {

    private final TimesheetService service;

    @PostMapping
    public ResponseEntity<ApiResponse<TimesheetEntry>> log(@RequestBody Map<String, Object> b) {
        TimesheetEntry e = service.log(
                LocalDate.parse(b.get("workDate").toString()),
                (String) b.get("project"), (String) b.get("task"),
                num(b.get("hours")), bool(b.get("billable")), (String) b.get("notes"));
        return ResponseEntity.ok(ApiResponse.ok(e, "Time logged"));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<TimesheetEntry>> update(
            @PathVariable UUID id, @RequestBody Map<String, Object> b) {
        TimesheetEntry e = service.update(id,
                (String) b.get("project"), (String) b.get("task"),
                num(b.get("hours")), bool(b.get("billable")), (String) b.get("notes"));
        return ResponseEntity.ok(ApiResponse.ok(e, "Entry updated"));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {
        service.delete(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Entry deleted"));
    }

    @PostMapping("/submit")
    public ResponseEntity<ApiResponse<Map<String, Object>>> submit(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        int n = service.submitRange(from, to);
        return ResponseEntity.ok(ApiResponse.ok(Map.of("submitted", n), n + " entries submitted"));
    }

    @PostMapping("/{id}/approve")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<TimesheetEntry>> approve(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.approve(id), "Approved"));
    }

    @PostMapping("/{id}/reject")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<TimesheetEntry>> reject(
            @PathVariable UUID id, @RequestBody(required = false) Map<String, Object> b) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.reject(id, b != null ? (String) b.get("reason") : null), "Rejected"));
    }

    @GetMapping("/me")
    public ResponseEntity<ApiResponse<List<TimesheetEntry>>> mine(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ResponseEntity.ok(ApiResponse.ok(service.myEntries(from, to)));
    }

    @GetMapping("/pending")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<List<TimesheetEntry>>> pending() {
        return ResponseEntity.ok(ApiResponse.ok(service.pending()));
    }

    @GetMapping("/summary")
    public ResponseEntity<ApiResponse<Map<String, Object>>> summary(
            @RequestParam(required = false) UUID userId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ResponseEntity.ok(ApiResponse.ok(service.summary(userId, from, to)));
    }

    private static boolean bool(Object o) {
        return o != null && Boolean.parseBoolean(o.toString());
    }

    private static BigDecimal num(Object o) {
        if (o == null) return null;
        if (o instanceof Number n) return new BigDecimal(n.toString());
        try {
            return new BigDecimal(o.toString());
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
