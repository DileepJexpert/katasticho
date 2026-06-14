package com.katasticho.erp.hr.controller;

import com.katasticho.erp.attendance.LeaveRequest;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.hr.entity.Holiday;
import com.katasticho.erp.hr.entity.LeaveType;
import com.katasticho.erp.hr.service.LeaveManagementService;
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

/** HR Leave Management (Time off) — Core HR module 1. */
@RestController
@RequestMapping("/api/v1/hr/leave")
@RequiredArgsConstructor
public class LeaveController {

    private final LeaveManagementService service;

    // ── Leave types (config — OWNER/ADMIN) ──

    @PostMapping("/types")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<LeaveType>> upsertType(@RequestBody Map<String, Object> b) {
        LeaveType t = service.upsertLeaveType(
                b.get("id") != null ? UUID.fromString(b.get("id").toString()) : null,
                (String) b.get("code"), (String) b.get("name"),
                bool(b.get("paid"), true), num(b.get("annualQuota")),
                (String) b.get("accrualMethod"), num(b.get("carryForwardMax")),
                bool(b.get("requiresApproval"), true), bool(b.get("active"), true));
        return ResponseEntity.ok(ApiResponse.ok(t, "Leave type saved"));
    }

    @GetMapping("/types")
    public ResponseEntity<ApiResponse<List<LeaveType>>> listTypes(
            @RequestParam(defaultValue = "false") boolean activeOnly) {
        return ResponseEntity.ok(ApiResponse.ok(service.listLeaveTypes(activeOnly)));
    }

    // ── Holiday calendar (OWNER/ADMIN to edit) ──

    @PostMapping("/holidays")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Holiday>> addHoliday(@RequestBody Map<String, Object> b) {
        Holiday h = service.addHoliday(LocalDate.parse(b.get("date").toString()),
                (String) b.get("name"), bool(b.get("optional"), false));
        return ResponseEntity.ok(ApiResponse.ok(h, "Holiday added"));
    }

    @DeleteMapping("/holidays/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Void>> deleteHoliday(@PathVariable UUID id) {
        service.deleteHoliday(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Holiday removed"));
    }

    @GetMapping("/holidays")
    public ResponseEntity<ApiResponse<List<Holiday>>> holidays(@RequestParam int year) {
        return ResponseEntity.ok(ApiResponse.ok(service.listHolidays(year)));
    }

    // ── Apply / decide ──

    @PostMapping("/apply")
    public ResponseEntity<ApiResponse<LeaveRequest>> apply(@RequestBody Map<String, Object> b) {
        LeaveRequest r = service.applyLeave(
                UUID.fromString(b.get("leaveTypeId").toString()),
                LocalDate.parse(b.get("fromDate").toString()),
                LocalDate.parse(b.get("toDate").toString()),
                (String) b.get("reason"));
        return ResponseEntity.ok(ApiResponse.ok(r, "Leave applied"));
    }

    @PostMapping("/{id}/approve")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<LeaveRequest>> approve(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.approveLeave(id), "Leave approved"));
    }

    @PostMapping("/{id}/reject")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<LeaveRequest>> reject(
            @PathVariable UUID id, @RequestBody(required = false) Map<String, Object> b) {
        String reason = b != null ? (String) b.get("reason") : null;
        return ResponseEntity.ok(ApiResponse.ok(service.rejectLeave(id, reason), "Leave rejected"));
    }

    @PostMapping("/{id}/cancel")
    public ResponseEntity<ApiResponse<LeaveRequest>> cancel(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.cancelLeave(id), "Leave cancelled"));
    }

    @GetMapping("/me")
    public ResponseEntity<ApiResponse<List<LeaveRequest>>> myLeaves() {
        return ResponseEntity.ok(ApiResponse.ok(service.myLeaves()));
    }

    @GetMapping("/pending")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<List<LeaveRequest>>> pending() {
        return ResponseEntity.ok(ApiResponse.ok(service.pendingLeaves()));
    }

    @GetMapping("/my-balances")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> myBalances(
            @RequestParam(required = false) Integer year) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.myBalances(year != null ? year : LocalDate.now().getYear())));
    }

    private static boolean bool(Object o, boolean dflt) {
        return o != null ? Boolean.parseBoolean(o.toString()) : dflt;
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
