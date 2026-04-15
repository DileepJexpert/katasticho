package com.katasticho.erp.organisation;

import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.dto.BranchResponse;
import com.katasticho.erp.organisation.dto.CreateBranchRequest;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link BranchService}. Covers the branch lifecycle rules
 * that the rest of the ERP depends on:
 *
 *   - duplicate code within an org is rejected
 *   - first branch for an org auto-flags as default
 *   - promoting a new default demotes the existing one
 *   - resolveBranchId validates an explicit id, or falls back to default
 *
 * Every downstream v1 feature (Invoice, Payment, Warehouse branch stamping
 * and the dashboard branch rollup) relies on these guarantees so they must
 * stay stable.
 */
@ExtendWith(MockitoExtension.class)
class BranchServiceTest {

    @Mock private BranchRepository branchRepository;
    @Mock private AuditService auditService;

    private BranchService branchService;
    private UUID orgId;
    private UUID userId;

    @BeforeEach
    void setUp() {
        branchService = new BranchService(branchRepository, auditService);
        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // ── createBranch ─────────────────────────────────────────────────

    @Test
    void createBranch_firstBranch_autoFlagsAsDefault() {
        CreateBranchRequest req = new CreateBranchRequest(
                "SEC62", "Sector 62 Store", null, null, null, null, null, null, null, null, null);

        when(branchRepository.existsByOrgIdAndCodeAndIsDeletedFalse(orgId, "SEC62"))
                .thenReturn(false);
        when(branchRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.empty());
        when(branchRepository.save(any(Branch.class)))
                .thenAnswer(inv -> {
                    Branch b = inv.getArgument(0);
                    b.setId(UUID.randomUUID());
                    return b;
                });

        BranchResponse resp = branchService.createBranch(req);

        ArgumentCaptor<Branch> captor = ArgumentCaptor.forClass(Branch.class);
        verify(branchRepository).save(captor.capture());
        assertTrue(captor.getValue().isDefault(),
                "First branch for an org must auto-flag as default");
        assertEquals("IN", captor.getValue().getCountry(),
                "Country should default to IN when not provided");
        assertTrue(resp.isDefault());
        verify(auditService).log(eq("BRANCH"), any(UUID.class), eq("CREATE"),
                isNull(), anyString());
    }

    @Test
    void createBranch_secondBranchNoFlag_doesNotBecomeDefault() {
        CreateBranchRequest req = new CreateBranchRequest(
                "SEC18", "Sector 18 Store", null, null, null, null, null, null, null, null, null);

        Branch existingDefault = Branch.builder()
                .code("SEC62").name("Sector 62 Store").isDefault(true).build();
        existingDefault.setId(UUID.randomUUID());

        when(branchRepository.existsByOrgIdAndCodeAndIsDeletedFalse(orgId, "SEC18"))
                .thenReturn(false);
        when(branchRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.of(existingDefault));
        when(branchRepository.save(any(Branch.class)))
                .thenAnswer(inv -> {
                    Branch b = inv.getArgument(0);
                    b.setId(UUID.randomUUID());
                    return b;
                });

        branchService.createBranch(req);

        // Exactly one save — the new branch. The existing default must NOT be
        // demoted because the new branch did not ask to be default.
        verify(branchRepository, times(1)).save(any(Branch.class));
        ArgumentCaptor<Branch> captor = ArgumentCaptor.forClass(Branch.class);
        verify(branchRepository).save(captor.capture());
        assertFalse(captor.getValue().isDefault());
    }

    @Test
    void createBranch_withExplicitDefault_demotesExistingDefault() {
        CreateBranchRequest req = new CreateBranchRequest(
                "SEC18", "Sector 18 Store", null, null, null, null, null, null, null, null, true);

        Branch existingDefault = Branch.builder()
                .code("SEC62").name("Sector 62 Store").isDefault(true).build();
        existingDefault.setId(UUID.randomUUID());

        when(branchRepository.existsByOrgIdAndCodeAndIsDeletedFalse(orgId, "SEC18"))
                .thenReturn(false);
        when(branchRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.of(existingDefault));
        when(branchRepository.save(any(Branch.class)))
                .thenAnswer(inv -> {
                    Branch b = inv.getArgument(0);
                    if (b.getId() == null) b.setId(UUID.randomUUID());
                    return b;
                });

        branchService.createBranch(req);

        // Two saves: (1) demote old default to false, (2) insert new default.
        ArgumentCaptor<Branch> captor = ArgumentCaptor.forClass(Branch.class);
        verify(branchRepository, times(2)).save(captor.capture());

        List<Branch> saved = captor.getAllValues();
        Branch demoted = saved.get(0);
        Branch created = saved.get(1);
        assertEquals("SEC62", demoted.getCode());
        assertFalse(demoted.isDefault(),
                "Existing default branch must be demoted when a new default is created");
        assertEquals("SEC18", created.getCode());
        assertTrue(created.isDefault());
    }

    @Test
    void createBranch_duplicateCode_throwsBusinessException() {
        CreateBranchRequest req = new CreateBranchRequest(
                "SEC62", "Another Sector 62", null, null, null, null, null, null, null, null, null);

        when(branchRepository.existsByOrgIdAndCodeAndIsDeletedFalse(orgId, "SEC62"))
                .thenReturn(true);

        BusinessException ex = assertThrows(BusinessException.class,
                () -> branchService.createBranch(req));
        assertEquals("ORG_DUPLICATE_BRANCH_CODE", ex.getErrorCode());
        verify(branchRepository, never()).save(any(Branch.class));
        verifyNoInteractions(auditService);
    }

    // ── resolveBranchId ──────────────────────────────────────────────

    @Test
    void resolveBranchId_explicitValid_returnsAsIs() {
        UUID branchId = UUID.randomUUID();
        Branch branch = Branch.builder().code("SEC62").name("Sector 62").build();
        branch.setId(branchId);

        when(branchRepository.findByIdAndOrgIdAndIsDeletedFalse(branchId, orgId))
                .thenReturn(Optional.of(branch));

        UUID resolved = branchService.resolveBranchId(branchId);

        assertEquals(branchId, resolved);
        // Must not fall through to the default lookup once the explicit id is validated.
        verify(branchRepository, never()).findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(any());
    }

    @Test
    void resolveBranchId_explicitInvalid_throwsNotFound() {
        UUID branchId = UUID.randomUUID();
        when(branchRepository.findByIdAndOrgIdAndIsDeletedFalse(branchId, orgId))
                .thenReturn(Optional.empty());

        BusinessException ex = assertThrows(BusinessException.class,
                () -> branchService.resolveBranchId(branchId));
        assertEquals("ERR_BRANCH_NOT_FOUND", ex.getErrorCode());
    }

    @Test
    void resolveBranchId_null_fallsBackToDefault() {
        UUID defaultId = UUID.randomUUID();
        Branch defaultBranch = Branch.builder().code("SEC62").isDefault(true).build();
        defaultBranch.setId(defaultId);

        when(branchRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.of(defaultBranch));

        UUID resolved = branchService.resolveBranchId(null);

        assertEquals(defaultId, resolved);
    }

    @Test
    void resolveBranchId_nullAndNoDefault_returnsNull() {
        when(branchRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.empty());

        assertNull(branchService.resolveBranchId(null),
                "No default branch for the org must produce a null branch id, not an exception");
    }

    // ── listBranches / getBranch ─────────────────────────────────────

    @Test
    void listBranches_returnsOrgScopedResults() {
        Branch b1 = Branch.builder().code("SEC62").name("Sector 62").isDefault(true).build();
        b1.setId(UUID.randomUUID());
        Branch b2 = Branch.builder().code("SEC18").name("Sector 18").build();
        b2.setId(UUID.randomUUID());

        when(branchRepository.findByOrgIdAndIsDeletedFalseOrderByName(orgId))
                .thenReturn(List.of(b1, b2));

        List<BranchResponse> responses = branchService.listBranches();

        assertEquals(2, responses.size());
        assertEquals("SEC62", responses.get(0).code());
        assertTrue(responses.get(0).isDefault());
        assertEquals("SEC18", responses.get(1).code());
        assertFalse(responses.get(1).isDefault());
    }

    @Test
    void getBranch_missing_throwsNotFound() {
        UUID branchId = UUID.randomUUID();
        when(branchRepository.findByIdAndOrgIdAndIsDeletedFalse(branchId, orgId))
                .thenReturn(Optional.empty());

        BusinessException ex = assertThrows(BusinessException.class,
                () -> branchService.getBranch(branchId));
        assertEquals("ERR_BRANCH_NOT_FOUND", ex.getErrorCode());
    }
}
