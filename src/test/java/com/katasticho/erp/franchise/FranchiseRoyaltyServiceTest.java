package com.katasticho.erp.franchise;

import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.franchise.dto.FranchiseRoyaltySettlementRequest;
import com.katasticho.erp.franchise.repository.FranchiseNodeRepository;
import com.katasticho.erp.franchise.repository.FranchiseRoyaltySettlementRepository;
import com.katasticho.erp.franchise.service.FranchiseRoyaltyService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class FranchiseRoyaltyServiceTest {

    @Mock private FranchiseRoyaltySettlementRepository settlementRepo;
    @Mock private FranchiseNodeRepository nodeRepo;

    @InjectMocks
    private FranchiseRoyaltyService royaltyService;

    private UUID orgId;
    private UUID nodeId;

    @BeforeEach
    void setUp() {
        orgId = UUID.randomUUID();
        nodeId = UUID.randomUUID();
    }

    @Test
    void calculateSettlement_rejectsUntilBranchSalesAndInvoiceIntegrationAreAvailable() {
        FranchiseRoyaltySettlementRequest req = new FranchiseRoyaltySettlementRequest();
        req.setFranchiseNodeId(nodeId);
        req.setPeriodStart(LocalDate.of(2026, 8, 1));
        req.setPeriodEnd(LocalDate.of(2026, 8, 31));

        BusinessException exception = assertThrows(BusinessException.class,
                () -> royaltyService.calculateSettlement(orgId, req));

        assertEquals("FRANCHISE_ROYALTY_UNAVAILABLE", exception.getErrorCode());
        verifyNoInteractions(nodeRepo, settlementRepo);
    }
}
