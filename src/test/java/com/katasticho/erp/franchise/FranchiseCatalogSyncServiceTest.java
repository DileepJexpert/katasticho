package com.katasticho.erp.franchise;

import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.franchise.dto.*;
import com.katasticho.erp.franchise.entity.FranchiseCatalogPolicy;
import com.katasticho.erp.franchise.entity.FranchiseNode;
import com.katasticho.erp.franchise.repository.BranchItemOverrideRepository;
import com.katasticho.erp.franchise.repository.FranchiseCatalogPolicyRepository;
import com.katasticho.erp.franchise.repository.FranchiseNodeRepository;
import com.katasticho.erp.franchise.service.FranchiseCatalogSyncService;
import com.katasticho.erp.inventory.repository.ItemRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class FranchiseCatalogSyncServiceTest {

    @Mock private FranchiseNodeRepository nodeRepo;
    @Mock private FranchiseCatalogPolicyRepository policyRepo;
    @Mock private BranchItemOverrideRepository overrideRepo;
    @Mock private ItemRepository itemRepo;

    @InjectMocks
    private FranchiseCatalogSyncService catalogSyncService;

    private UUID orgId;
    private UUID branchId;
    private UUID itemId;

    @BeforeEach
    void setUp() {
        orgId = UUID.randomUUID();
        branchId = UUID.randomUUID();
        itemId = UUID.randomUUID();
    }

    @Test
    void createNode_succeeds() {
        FranchiseNodeRequest req = new FranchiseNodeRequest();
        req.setNodeCode("FR-MUM-01");
        req.setNodeName("Katixo Mumbai");
        req.setNodeType("FOFO");

        when(nodeRepo.findByOrgIdAndNodeCode(orgId, "FR-MUM-01")).thenReturn(Optional.empty());
        when(nodeRepo.save(any(FranchiseNode.class))).thenAnswer(i -> {
            FranchiseNode n = i.getArgument(0);
            n.setId(UUID.randomUUID());
            return n;
        });

        FranchiseNodeResponse resp = catalogSyncService.createNode(orgId, req);

        assertNotNull(resp.getId());
        assertEquals("FR-MUM-01", resp.getNodeCode());
        assertEquals("Katixo Mumbai", resp.getNodeName());
    }

    @Test
    void pushCatalogToBranches_rejectsUntilOrganisationToBranchIntegrationIsAvailable() {
        CatalogSyncPushRequest req = new CatalogSyncPushRequest();
        BusinessException exception = assertThrows(BusinessException.class,
                () -> catalogSyncService.pushCatalogToBranches(orgId, req));

        assertEquals("FRANCHISE_INTEGRATION_UNAVAILABLE", exception.getErrorCode());
        verifyNoInteractions(nodeRepo, itemRepo, overrideRepo, policyRepo);
    }

    @Test
    void savePriceOverride_rejectsUntilOrganisationToBranchIntegrationIsAvailable() {
        BranchPriceOverrideRequest req = new BranchPriceOverrideRequest();
        req.setBranchId(branchId);
        req.setItemId(itemId);
        req.setCustomSellingPrice(java.math.BigDecimal.valueOf(25));

        BusinessException exception = assertThrows(BusinessException.class,
                () -> catalogSyncService.savePriceOverride(orgId, req));

        assertEquals("FRANCHISE_INTEGRATION_UNAVAILABLE", exception.getErrorCode());
        verifyNoInteractions(nodeRepo, itemRepo, overrideRepo, policyRepo);
    }
}
