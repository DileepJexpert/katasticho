package com.katasticho.erp.payroll.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.entity.EmployeeTaxDeclaration;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import com.katasticho.erp.payroll.service.Form12BBPdfService;
import com.katasticho.erp.payroll.service.TaxDeclarationService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * Authorization regression tests for {@link TaxDeclarationController}. The bug:
 * the owner-or-admin gate was {@code if (me != null && !owner) ensureAdmin()},
 * which SKIPPED the admin check entirely when the caller has no linked Employee
 * ({@code me == null}) — letting any authenticated non-admin read/submit/delete
 * ANY employee's Form 12BB (PAN, rent, deduction PII). The fix forces the admin
 * gate when {@code me == null}.
 */
@ExtendWith(MockitoExtension.class)
class TaxDeclarationControllerAuthzTest {

    @Mock private TaxDeclarationService service;
    @Mock private EmployeeRepository employeeRepository;
    @Mock private Form12BBPdfService form12BBPdfService;

    private TaxDeclarationController controller;
    private UUID orgId;
    private UUID userId;

    @BeforeEach
    void setUp() {
        controller = new TaxDeclarationController(service, employeeRepository, form12BBPdfService);
        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
        SecurityContextHolder.clearContext();
    }

    private void authAs(String role) {
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken("u", "p",
                        List.of(new SimpleGrantedAuthority(role))));
    }

    private EmployeeTaxDeclaration declFor(UUID employeeId) {
        return EmployeeTaxDeclaration.builder()
                .id(UUID.randomUUID()).orgId(orgId).employeeId(employeeId).build();
    }

    @Test
    void nonAdminWithNoLinkedEmployee_cannotSubmitOthersDeclaration() {
        when(employeeRepository.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, userId))
                .thenReturn(Optional.empty()); // resolveMeOrNull() → null
        authAs("ROLE_OPERATOR");
        UUID id = UUID.randomUUID();
        when(service.get(id)).thenReturn(declFor(UUID.randomUUID())); // someone else's

        BusinessException ex = assertThrows(BusinessException.class, () -> controller.submit(id));
        assertEquals("TAX_DECL_NOT_OWNER", ex.getErrorCode());
        verify(service, never()).submit(any());
    }

    @Test
    void nonAdminWithNoLinkedEmployee_cannotDownloadOthersForm12BB() {
        when(employeeRepository.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, userId))
                .thenReturn(Optional.empty());
        authAs("ROLE_VIEWER");
        UUID id = UUID.randomUUID();
        when(service.get(id)).thenReturn(declFor(UUID.randomUUID()));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> controller.downloadForm12BB(id));
        assertEquals("TAX_DECL_NOT_OWNER", ex.getErrorCode());
        verify(form12BBPdfService, never()).generatePdf(any());
    }

    @Test
    void adminWithNoLinkedEmployee_isAllowed() {
        when(employeeRepository.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, userId))
                .thenReturn(Optional.empty());
        authAs("ROLE_ADMIN");
        UUID id = UUID.randomUUID();
        EmployeeTaxDeclaration d = declFor(UUID.randomUUID());
        when(service.get(id)).thenReturn(d);
        when(service.submit(id)).thenReturn(d);

        assertDoesNotThrow(() -> controller.submit(id));
        verify(service).submit(id);
    }

    @Test
    void ownerCanSubmitOwnDeclaration() {
        UUID empId = UUID.randomUUID();
        Employee me = Employee.builder().id(empId).orgId(orgId).userId(userId).build();
        when(employeeRepository.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, userId))
                .thenReturn(Optional.of(me));
        authAs("ROLE_OPERATOR");
        UUID id = UUID.randomUUID();
        EmployeeTaxDeclaration d = declFor(empId); // caller's own declaration
        when(service.get(id)).thenReturn(d);
        when(service.submit(id)).thenReturn(d);

        assertDoesNotThrow(() -> controller.submit(id));
        verify(service).submit(id);
    }
}
