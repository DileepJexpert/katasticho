package com.katasticho.erp.fieldsales.service;

import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class FieldHierarchyServiceTest {

    @Mock private AppUserRepository appUserRepository;
    private FieldHierarchyService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID mgr = UUID.randomUUID();
    private final UUID a = UUID.randomUUID();
    private final UUID b = UUID.randomUUID();
    private final UUID c = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new FieldHierarchyService(appUserRepository);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(mgr);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private AppUser user(UUID id, UUID managerId) {
        AppUser u = AppUser.builder().fullName("U").role("OPERATOR").reportsToUserId(managerId).build();
        u.setId(id);
        u.setOrgId(orgId);
        return u;
    }

    private void reports(UUID managerId, AppUser... children) {
        when(appUserRepository.findByOrgIdAndReportsToUserIdAndIsDeletedFalseOrderByFullNameAsc(orgId, managerId))
                .thenReturn(List.of(children));
    }

    @Test
    void downlineUserIds_collectsTransitiveReports() {
        // mgr -> {a, b}; a -> {c}
        reports(mgr, user(a, mgr), user(b, mgr));
        reports(a, user(c, a));
        reports(b);
        reports(c);

        Set<UUID> downline = service.downlineUserIds(mgr);

        assertEquals(Set.of(a, b, c), downline);
    }

    @Test
    void isAncestor_walksUpReportingChain() {
        // c -> a -> mgr -> (top)
        when(appUserRepository.findByIdAndOrgIdAndIsDeletedFalse(c, orgId))
                .thenReturn(Optional.of(user(c, a)));
        when(appUserRepository.findByIdAndOrgIdAndIsDeletedFalse(a, orgId))
                .thenReturn(Optional.of(user(a, mgr)));
        when(appUserRepository.findByIdAndOrgIdAndIsDeletedFalse(mgr, orgId))
                .thenReturn(Optional.of(user(mgr, null)));

        assertTrue(service.isAncestor(mgr, c));   // mgr is two levels above c
        assertFalse(service.isAncestor(c, mgr));  // c is below mgr, not an ancestor
    }

    @Test
    void assignManager_self_throws() {
        when(appUserRepository.findByIdAndOrgIdAndIsDeletedFalse(mgr, orgId))
                .thenReturn(Optional.of(user(mgr, null)));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.assignManager(mgr, mgr));
        assertEquals("FH_SELF_MANAGER", ex.getErrorCode());
    }

    @Test
    void assignManager_cycle_throws() {
        // Try to make mgr report to 'a', who already reports to mgr -> cycle.
        when(appUserRepository.findByIdAndOrgIdAndIsDeletedFalse(mgr, orgId))
                .thenReturn(Optional.of(user(mgr, null)));
        when(appUserRepository.findByIdAndOrgIdAndIsDeletedFalse(a, orgId))
                .thenReturn(Optional.of(user(a, mgr)));
        reports(mgr, user(a, mgr));
        reports(a);

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.assignManager(mgr, a));
        assertEquals("FH_CYCLE", ex.getErrorCode());
    }

    @Test
    void assignManager_validManager_persists() {
        when(appUserRepository.findByIdAndOrgIdAndIsDeletedFalse(a, orgId))
                .thenReturn(Optional.of(user(a, null)));
        when(appUserRepository.findByIdAndOrgIdAndIsDeletedFalse(mgr, orgId))
                .thenReturn(Optional.of(user(mgr, null)));
        reports(a); // a has no downline, so mgr isn't in it
        when(appUserRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        AppUser saved = service.assignManager(a, mgr);

        assertEquals(mgr, saved.getReportsToUserId());
    }
}
