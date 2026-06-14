package com.katasticho.erp.hr.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.hr.entity.HrTicket;
import com.katasticho.erp.hr.entity.HrTicketComment;
import com.katasticho.erp.hr.service.HrHelpDeskService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/** HR Help Desk — Core HR module 6. */
@RestController
@RequestMapping("/api/v1/hr/helpdesk")
@RequiredArgsConstructor
public class HrHelpDeskController {

    private final HrHelpDeskService service;

    @PostMapping("/tickets")
    public ResponseEntity<ApiResponse<HrTicket>> raise(@RequestBody Map<String, Object> b) {
        HrTicket t = service.raise(
                (String) b.get("category"), (String) b.get("subject"),
                (String) b.get("description"), (String) b.get("priority"));
        return ResponseEntity.ok(ApiResponse.ok(t, "Ticket raised"));
    }

    @GetMapping("/tickets/{id}")
    public ResponseEntity<ApiResponse<Map<String, Object>>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getTicket(id)));
    }

    @PostMapping("/tickets/{id}/comments")
    public ResponseEntity<ApiResponse<HrTicketComment>> comment(
            @PathVariable UUID id, @RequestBody Map<String, Object> b) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.addComment(id, (String) b.get("body")), "Comment added"));
    }

    @PostMapping("/tickets/{id}/assign")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<HrTicket>> assign(
            @PathVariable UUID id, @RequestBody Map<String, Object> b) {
        UUID assignee = b.get("assigneeId") != null
                ? UUID.fromString(b.get("assigneeId").toString()) : null;
        return ResponseEntity.ok(ApiResponse.ok(service.assign(id, assignee), "Ticket assigned"));
    }

    @PostMapping("/tickets/{id}/status")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<HrTicket>> setStatus(
            @PathVariable UUID id, @RequestBody Map<String, Object> b) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.setStatus(id, (String) b.get("status"), (String) b.get("resolution")),
                "Status updated"));
    }

    @GetMapping("/tickets/me")
    public ResponseEntity<ApiResponse<List<HrTicket>>> mine() {
        return ResponseEntity.ok(ApiResponse.ok(service.myTickets()));
    }

    @GetMapping("/tickets/assigned-to-me")
    public ResponseEntity<ApiResponse<List<HrTicket>>> assignedToMe() {
        return ResponseEntity.ok(ApiResponse.ok(service.assignedToMe()));
    }

    @GetMapping("/tickets/open")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<List<HrTicket>>> open() {
        return ResponseEntity.ok(ApiResponse.ok(service.openTickets()));
    }
}
