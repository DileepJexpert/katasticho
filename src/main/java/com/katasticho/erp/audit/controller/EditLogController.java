package com.katasticho.erp.audit.controller;

import com.katasticho.erp.audit.service.EditLogService;
import com.katasticho.erp.audit.service.EditLogService.EditLogEntryResponse;
import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.Map;
import java.util.UUID;

/**
 * Query endpoints over the append-only edit log (MCA audit trail).
 * Read-only by construction — there is no write endpoint to guard.
 */
@RestController
@RequestMapping("/api/v1/audit")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
public class EditLogController {

    private final EditLogService editLogService;

    @GetMapping("/edit-log")
    public ResponseEntity<ApiResponse<Page<EditLogEntryResponse>>> list(
            @RequestParam(required = false) String entityType,
            @RequestParam(required = false) UUID entityId,
            @RequestParam(required = false) String action,
            @RequestParam(required = false) UUID userId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {
        Page<EditLogEntryResponse> result = editLogService.list(
                entityType, entityId, action, userId, from, to,
                PageRequest.of(page, Math.min(size, 200),
                        Sort.by(Sort.Direction.DESC, "changedAt")));
        return ResponseEntity.ok(ApiResponse.ok(result));
    }

    @GetMapping("/edit-log/summary")
    public ResponseEntity<ApiResponse<Map<String, Object>>> summary(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ResponseEntity.ok(ApiResponse.ok(editLogService.summary(from, to)));
    }
}
