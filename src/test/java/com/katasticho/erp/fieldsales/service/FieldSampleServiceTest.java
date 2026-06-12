package com.katasticho.erp.fieldsales.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.fieldsales.entity.FieldSampleTxn;
import com.katasticho.erp.fieldsales.repository.FieldSampleTxnRepository;
import com.katasticho.erp.fieldsales.repository.VisitProductLogRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class FieldSampleServiceTest {

    @Mock private FieldSampleTxnRepository txnRepo;
    @Mock private VisitProductLogRepository vplRepo;

    private FieldSampleService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final UUID salespersonId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new FieldSampleService(txnRepo, vplRepo);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void record_issue_stampsOrgAndCreator() {
        when(txnRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        FieldSampleTxn txn = service.record("ISSUE", salespersonId, null,
                "Crocin Strip", 50, LocalDate.of(2026, 6, 12), null);

        assertEquals(orgId, txn.getOrgId());
        assertEquals(userId, txn.getCreatedBy());
        assertEquals("ISSUE", txn.getTxnType());
        assertEquals(50, txn.getQuantity());
    }

    @Test
    void record_zeroQty_throws() {
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.record("ISSUE", salespersonId, null, "Crocin", 0, null, null));
        assertEquals("FS_SAMPLE_QTY_INVALID", ex.getErrorCode());
    }

    @Test
    void record_blankProduct_throws() {
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.record("ISSUE", salespersonId, null, "  ", 5, null, null));
        assertEquals("FS_SAMPLE_PRODUCT_REQUIRED", ex.getErrorCode());
    }

    @Test
    void balance_mergesIssuesReturnsAndDistribution() {
        // 100 issued, 10 returned of Crocin; 20 distributed via visits.
        // 5 distributed of "Promo Pen" that was never formally issued.
        when(txnRepo.sumByProduct(orgId, salespersonId)).thenReturn(List.<Object[]>of(
                new Object[]{"Crocin Strip", 100L, 10L}));
        when(vplRepo.sumDistributedByProduct(orgId, salespersonId)).thenReturn(List.of(
                new Object[]{"crocin strip", 20L},
                new Object[]{"Promo Pen", 5L}));

        List<Map<String, Object>> balance = service.balance(salespersonId);

        assertEquals(2, balance.size());
        Map<String, Object> crocin = balance.stream()
                .filter(r -> r.get("productName").equals("Crocin Strip")).findFirst().orElseThrow();
        assertEquals(100L, crocin.get("issued"));
        assertEquals(10L, crocin.get("returned"));
        assertEquals(20L, crocin.get("distributed"));
        assertEquals(70L, crocin.get("balance"));

        Map<String, Object> pen = balance.stream()
                .filter(r -> r.get("productName").equals("Promo Pen")).findFirst().orElseThrow();
        assertEquals(-5L, pen.get("balance"));
    }

    @Test
    void balance_emptyWhenNoActivity() {
        when(txnRepo.sumByProduct(orgId, salespersonId)).thenReturn(List.of());
        when(vplRepo.sumDistributedByProduct(orgId, salespersonId)).thenReturn(List.of());

        assertTrue(service.balance(salespersonId).isEmpty());
    }
}
