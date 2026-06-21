package com.katasticho.erp.payroll.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.entity.EmployeeTaxDeclaration;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import com.katasticho.erp.payroll.service.TaxDeclarationService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Per-employee tax declaration (Form 12BB) + regime endpoints. Two surfaces:
 * <ul>
 *   <li><b>/me</b> — self-service: any authenticated user reads/edits/submits
 *       their own declaration.</li>
 *   <li><b>/{employeeId}, /verify</b> — admin: payroll team views the org's
 *       declarations and verifies after IT-proof check.</li>
 * </ul>
 */
@RestController
@RequestMapping("/api/v1/payroll/tax-declarations")
@RequiredArgsConstructor
@PreAuthorize("isAuthenticated()")
public class TaxDeclarationController {

    private final TaxDeclarationService service;
    private final EmployeeRepository employeeRepository;

    // ── Self-service /me ─────────────────────────────────────────

    @GetMapping("/me")
    public ResponseEntity<ApiResponse<EmployeeTaxDeclaration>> myDeclaration(
            @RequestParam("fy") String fiscalYear) {
        Employee me = resolveMe();
        Optional<EmployeeTaxDeclaration> d = service.findForEmployee(me.getId(), fiscalYear);
        return ResponseEntity.ok(ApiResponse.ok(d.orElse(null)));
    }

    @PutMapping("/me")
    public ResponseEntity<ApiResponse<EmployeeTaxDeclaration>> upsertMine(
            @RequestParam("fy") String fiscalYear,
            @RequestBody EmployeeTaxDeclaration body) {
        Employee me = resolveMe();
        return ResponseEntity.ok(ApiResponse.ok(
                service.upsert(me.getId(), fiscalYear, body), "Declaration saved"));
    }

    @PostMapping("/{id}/submit")
    public ResponseEntity<ApiResponse<EmployeeTaxDeclaration>> submit(@PathVariable UUID id) {
        EmployeeTaxDeclaration d = service.get(id);
        Employee me = resolveMeOrNull();
        if (me != null && !d.getEmployeeId().equals(me.getId())) {
            ensureAdmin();
        }
        return ResponseEntity.ok(ApiResponse.ok(service.submit(id), "Declaration submitted"));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteDraft(@PathVariable UUID id) {
        EmployeeTaxDeclaration d = service.get(id);
        Employee me = resolveMeOrNull();
        if (me != null && !d.getEmployeeId().equals(me.getId())) {
            ensureAdmin();
        }
        service.delete(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Declaration removed"));
    }

    // ── Admin / payroll ──────────────────────────────────────────

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<List<EmployeeTaxDeclaration>>> listForFy(
            @RequestParam("fy") String fiscalYear) {
        return ResponseEntity.ok(ApiResponse.ok(service.listForFy(fiscalYear)));
    }

    @GetMapping("/employees/{employeeId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<EmployeeTaxDeclaration>> forEmployee(
            @PathVariable UUID employeeId, @RequestParam("fy") String fiscalYear) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.findForEmployee(employeeId, fiscalYear).orElse(null)));
    }

    @PostMapping("/{id}/verify")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<EmployeeTaxDeclaration>> verify(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.verify(id), "Declaration verified"));
    }

    // ── helpers ──────────────────────────────────────────────────

    private Employee resolveMe() {
        Employee me = resolveMeOrNull();
        if (me == null) throw new BusinessException(
                "Your login is not linked to an employee record. Set up your profile first.",
                "HR_EMPLOYEE_NOT_LINKED", HttpStatus.NOT_FOUND);
        return me;
    }

    private Employee resolveMeOrNull() {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        if (userId == null) return null;
        return employeeRepository.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, userId).orElse(null);
    }

    private void ensureAdmin() {
        boolean isAdmin = org.springframework.security.core.context.SecurityContextHolder
                .getContext().getAuthentication().getAuthorities().stream()
                .map(a -> a.getAuthority())
                .anyMatch(r -> r.equals("ROLE_OWNER") || r.equals("ROLE_ADMIN") || r.equals("ROLE_ACCOUNTANT"));
        if (!isAdmin) throw new BusinessException(
                "Not your declaration", "TAX_DECL_NOT_OWNER", HttpStatus.FORBIDDEN);
    }
}
