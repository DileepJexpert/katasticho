package com.katasticho.erp.fieldsales.controller;

import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.fieldsales.service.FieldHierarchyService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.*;

/** Field reporting hierarchy: assign managers, view the org chart and my team. */
@RestController
@RequestMapping("/api/v1/field-sales/hierarchy")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.FIELD_SALES)
@PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
public class FieldHierarchyController {

    private final FieldHierarchyService service;

    /** Set or clear (managerId null/absent) a user's reporting manager. */
    @PutMapping("/users/{userId}/manager")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> setManager(
            @PathVariable UUID userId, @RequestBody(required = false) Map<String, Object> body) {
        UUID managerId = body != null && body.get("managerId") != null
                ? UUID.fromString(body.get("managerId").toString()) : null;
        AppUser u = service.assignManager(userId, managerId);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("userId", u.getId());
        out.put("reportsToUserId", u.getReportsToUserId());
        return ResponseEntity.ok(ApiResponse.ok(out, "Reporting manager updated"));
    }

    @GetMapping("/org-chart")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> orgChart() {
        return ResponseEntity.ok(ApiResponse.ok(service.orgChart()));
    }

    /** The current user's direct reports + total downline size. */
    @GetMapping("/my-team")
    public ResponseEntity<ApiResponse<Map<String, Object>>> myTeam() {
        UUID me = TenantContext.getCurrentUserId();
        List<Map<String, Object>> reports = new ArrayList<>();
        for (AppUser u : service.directReports(me)) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("userId", u.getId());
            row.put("fullName", u.getFullName());
            row.put("role", u.getRole());
            reports.add(row);
        }
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("directReports", reports);
        out.put("downlineCount", service.downlineUserIds(me).size());
        return ResponseEntity.ok(ApiResponse.ok(out));
    }
}
