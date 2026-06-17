package com.katasticho.erp.hr.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.hr.entity.EmployeeEducation;
import com.katasticho.erp.hr.entity.EmployeeExperience;
import com.katasticho.erp.hr.entity.EmployeeFamily;
import com.katasticho.erp.hr.service.HrEmployeeService;
import com.katasticho.erp.payroll.entity.Employee;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * HR self-service endpoints for the logged-in employee. Any authenticated
 * user (including OPERATOR) can read and edit their own profile + family
 * / education / experience. Writes go through HrEmployeeService.updateMe
 * which only persists the self-editable field set — manager-controlled
 * fields (designation, department, salary, statutory IDs, etc.) stay
 * locked.
 */
@RestController
@RequestMapping("/api/v1/hr/employees/me")
@RequiredArgsConstructor
@PreAuthorize("isAuthenticated()")
public class MyProfileController {

    private final HrEmployeeService service;

    @GetMapping
    public ResponseEntity<ApiResponse<Map<String, Object>>> me() {
        return ResponseEntity.ok(ApiResponse.ok(service.myProfile()));
    }

    @PutMapping
    public ResponseEntity<ApiResponse<Employee>> updateMe(@RequestBody Employee body) {
        return ResponseEntity.ok(ApiResponse.ok(service.updateMe(body), "Profile updated"));
    }

    // ── Family ──

    @PostMapping("/family")
    public ResponseEntity<ApiResponse<EmployeeFamily>> addFamily(@RequestBody EmployeeFamily body) {
        UUID employeeId = service.me().getId();
        return ResponseEntity.ok(ApiResponse.ok(
                service.addFamily(employeeId, body), "Family member added"));
    }

    @PutMapping("/family/{id}")
    public ResponseEntity<ApiResponse<EmployeeFamily>> updateFamily(
            @PathVariable UUID id, @RequestBody EmployeeFamily body) {
        ensureOwnsFamily(id);
        return ResponseEntity.ok(ApiResponse.ok(service.updateFamily(id, body), "Updated"));
    }

    @DeleteMapping("/family/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteFamily(@PathVariable UUID id) {
        ensureOwnsFamily(id);
        service.deleteFamily(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Removed"));
    }

    // ── Education ──

    @PostMapping("/education")
    public ResponseEntity<ApiResponse<EmployeeEducation>> addEducation(@RequestBody EmployeeEducation body) {
        UUID employeeId = service.me().getId();
        return ResponseEntity.ok(ApiResponse.ok(
                service.addEducation(employeeId, body), "Education added"));
    }

    @PutMapping("/education/{id}")
    public ResponseEntity<ApiResponse<EmployeeEducation>> updateEducation(
            @PathVariable UUID id, @RequestBody EmployeeEducation body) {
        ensureOwnsEducation(id);
        return ResponseEntity.ok(ApiResponse.ok(service.updateEducation(id, body), "Updated"));
    }

    @DeleteMapping("/education/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteEducation(@PathVariable UUID id) {
        ensureOwnsEducation(id);
        service.deleteEducation(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Removed"));
    }

    // ── Experience ──

    @PostMapping("/experience")
    public ResponseEntity<ApiResponse<EmployeeExperience>> addExperience(@RequestBody EmployeeExperience body) {
        UUID employeeId = service.me().getId();
        return ResponseEntity.ok(ApiResponse.ok(
                service.addExperience(employeeId, body), "Experience added"));
    }

    @PutMapping("/experience/{id}")
    public ResponseEntity<ApiResponse<EmployeeExperience>> updateExperience(
            @PathVariable UUID id, @RequestBody EmployeeExperience body) {
        ensureOwnsExperience(id);
        return ResponseEntity.ok(ApiResponse.ok(service.updateExperience(id, body), "Updated"));
    }

    @DeleteMapping("/experience/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteExperience(@PathVariable UUID id) {
        ensureOwnsExperience(id);
        service.deleteExperience(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Removed"));
    }

    // ── Ownership guards: a /me caller can only touch their own subresources ──

    private void ensureOwnsFamily(UUID familyId) {
        UUID myEmployeeId = service.me().getId();
        boolean owns = service.listFamily(myEmployeeId).stream()
                .anyMatch(f -> familyId.equals(f.getId()));
        if (!owns) {
            throw new com.katasticho.erp.common.exception.BusinessException(
                    "Not your record", "HR_NOT_OWNER", org.springframework.http.HttpStatus.FORBIDDEN);
        }
    }

    private void ensureOwnsEducation(UUID id) {
        UUID myEmployeeId = service.me().getId();
        boolean owns = service.listEducation(myEmployeeId).stream()
                .anyMatch(e -> id.equals(e.getId()));
        if (!owns) {
            throw new com.katasticho.erp.common.exception.BusinessException(
                    "Not your record", "HR_NOT_OWNER", org.springframework.http.HttpStatus.FORBIDDEN);
        }
    }

    private void ensureOwnsExperience(UUID id) {
        UUID myEmployeeId = service.me().getId();
        boolean owns = service.listExperience(myEmployeeId).stream()
                .anyMatch(x -> id.equals(x.getId()));
        if (!owns) {
            throw new com.katasticho.erp.common.exception.BusinessException(
                    "Not your record", "HR_NOT_OWNER", org.springframework.http.HttpStatus.FORBIDDEN);
        }
    }
}
