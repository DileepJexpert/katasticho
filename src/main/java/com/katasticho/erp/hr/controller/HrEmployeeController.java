package com.katasticho.erp.hr.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.hr.entity.EmployeeEducation;
import com.katasticho.erp.hr.entity.EmployeeExperience;
import com.katasticho.erp.hr.entity.EmployeeFamily;
import com.katasticho.erp.hr.service.HrEmployeeService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/**
 * HR module 2 — employee subresources (family, education, prior experience).
 * Self-service /me endpoints land in step 3.
 */
@RestController
@RequestMapping("/api/v1/hr/employees")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
public class HrEmployeeController {

    private final HrEmployeeService service;

    // ── Family ──

    @GetMapping("/{employeeId}/family")
    public ResponseEntity<ApiResponse<List<EmployeeFamily>>> listFamily(@PathVariable UUID employeeId) {
        return ResponseEntity.ok(ApiResponse.ok(service.listFamily(employeeId)));
    }

    @PostMapping("/{employeeId}/family")
    public ResponseEntity<ApiResponse<EmployeeFamily>> addFamily(
            @PathVariable UUID employeeId,
            @RequestBody EmployeeFamily body) {
        return ResponseEntity.ok(ApiResponse.ok(service.addFamily(employeeId, body), "Family member added"));
    }

    @PutMapping("/family/{id}")
    public ResponseEntity<ApiResponse<EmployeeFamily>> updateFamily(
            @PathVariable UUID id, @RequestBody EmployeeFamily body) {
        return ResponseEntity.ok(ApiResponse.ok(service.updateFamily(id, body), "Updated"));
    }

    @DeleteMapping("/family/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteFamily(@PathVariable UUID id) {
        service.deleteFamily(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Removed"));
    }

    // ── Education ──

    @GetMapping("/{employeeId}/education")
    public ResponseEntity<ApiResponse<List<EmployeeEducation>>> listEducation(@PathVariable UUID employeeId) {
        return ResponseEntity.ok(ApiResponse.ok(service.listEducation(employeeId)));
    }

    @PostMapping("/{employeeId}/education")
    public ResponseEntity<ApiResponse<EmployeeEducation>> addEducation(
            @PathVariable UUID employeeId, @RequestBody EmployeeEducation body) {
        return ResponseEntity.ok(ApiResponse.ok(service.addEducation(employeeId, body), "Education added"));
    }

    @PutMapping("/education/{id}")
    public ResponseEntity<ApiResponse<EmployeeEducation>> updateEducation(
            @PathVariable UUID id, @RequestBody EmployeeEducation body) {
        return ResponseEntity.ok(ApiResponse.ok(service.updateEducation(id, body), "Updated"));
    }

    @DeleteMapping("/education/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteEducation(@PathVariable UUID id) {
        service.deleteEducation(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Removed"));
    }

    // ── Experience ──

    @GetMapping("/{employeeId}/experience")
    public ResponseEntity<ApiResponse<List<EmployeeExperience>>> listExperience(@PathVariable UUID employeeId) {
        return ResponseEntity.ok(ApiResponse.ok(service.listExperience(employeeId)));
    }

    @PostMapping("/{employeeId}/experience")
    public ResponseEntity<ApiResponse<EmployeeExperience>> addExperience(
            @PathVariable UUID employeeId, @RequestBody EmployeeExperience body) {
        return ResponseEntity.ok(ApiResponse.ok(service.addExperience(employeeId, body), "Experience added"));
    }

    @PutMapping("/experience/{id}")
    public ResponseEntity<ApiResponse<EmployeeExperience>> updateExperience(
            @PathVariable UUID id, @RequestBody EmployeeExperience body) {
        return ResponseEntity.ok(ApiResponse.ok(service.updateExperience(id, body), "Updated"));
    }

    @DeleteMapping("/experience/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteExperience(@PathVariable UUID id) {
        service.deleteExperience(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Removed"));
    }
}
