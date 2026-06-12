package com.katasticho.erp.attendance;

import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** Attendance punches + leave requests. Open to all authenticated staff; manager actions OWNER/ADMIN. */
@RestController
@RequestMapping("/api/v1/attendance")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
public class AttendanceController {

    private final AttendanceService service;

    @PostMapping("/punch-in")
    public ResponseEntity<ApiResponse<FieldAttendance>> punchIn(
            @RequestBody(required = false) Map<String, Object> body) {
        return ResponseEntity.ok(ApiResponse.ok(service.punchIn(
                decimal(body, "latitude"), decimal(body, "longitude"),
                body != null ? (String) body.get("notes") : null), "Punched in"));
    }

    @PostMapping("/punch-out")
    public ResponseEntity<ApiResponse<FieldAttendance>> punchOut(
            @RequestBody(required = false) Map<String, Object> body) {
        return ResponseEntity.ok(ApiResponse.ok(service.punchOut(
                decimal(body, "latitude"), decimal(body, "longitude")), "Punched out"));
    }

    @GetMapping("/today")
    public ResponseEntity<ApiResponse<FieldAttendance>> today() {
        return ResponseEntity.ok(ApiResponse.ok(service.today().orElse(null)));
    }

    @GetMapping("/me")
    public ResponseEntity<ApiResponse<List<FieldAttendance>>> myMonth(
            @RequestParam(required = false) LocalDate month) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.myMonth(month != null ? month : LocalDate.now())));
    }

    @GetMapping("/team")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> team(
            @RequestParam(required = false) LocalDate date) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.teamOnDate(date != null ? date : LocalDate.now())));
    }

    // ── Leave ───────────────────────────────────────────────────────────

    @PostMapping("/leave")
    public ResponseEntity<ApiResponse<LeaveRequest>> applyLeave(@RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(ApiResponse.ok(service.applyLeave(
                LocalDate.parse(body.get("fromDate").toString()),
                LocalDate.parse(body.get("toDate").toString()),
                (String) body.get("leaveType"),
                (String) body.get("reason")), "Leave requested"));
    }

    @GetMapping("/leave/me")
    public ResponseEntity<ApiResponse<List<LeaveRequest>>> myLeaves() {
        return ResponseEntity.ok(ApiResponse.ok(service.myLeaves()));
    }

    @PostMapping("/leave/{id}/cancel")
    public ResponseEntity<ApiResponse<LeaveRequest>> cancelLeave(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.cancelLeave(id), "Leave cancelled"));
    }

    @GetMapping("/leave/pending")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<List<LeaveRequest>>> pendingLeaves() {
        return ResponseEntity.ok(ApiResponse.ok(service.pendingLeaves()));
    }

    @PostMapping("/leave/{id}/approve")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<LeaveRequest>> approveLeave(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.approveLeave(id), "Leave approved"));
    }

    @PostMapping("/leave/{id}/reject")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<LeaveRequest>> rejectLeave(
            @PathVariable UUID id, @RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.rejectLeave(id, (String) body.get("reason")), "Leave rejected"));
    }

    private static BigDecimal decimal(Map<String, Object> body, String key) {
        return body != null && body.get(key) != null
                ? new BigDecimal(body.get(key).toString()) : null;
    }
}
