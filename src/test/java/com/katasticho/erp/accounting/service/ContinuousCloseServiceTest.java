package com.katasticho.erp.accounting.service;

import com.katasticho.erp.accounting.entity.FiscalPeriod;
import com.katasticho.erp.accounting.repository.FiscalPeriodRepository;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.amortization.repository.AmortizationEntryRepository;
import com.katasticho.erp.amortization.repository.AmortizationScheduleRepository;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.asset.entity.FixedAsset;
import com.katasticho.erp.asset.repository.FixedAssetDepreciationRepository;
import com.katasticho.erp.asset.repository.FixedAssetRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ContinuousCloseServiceTest {

    @Mock private FiscalPeriodRepository fiscalPeriodRepository;
    @Mock private InvoiceRepository invoiceRepository;
    @Mock private PurchaseBillRepository purchaseBillRepository;
    @Mock private FixedAssetRepository fixedAssetRepository;
    @Mock private FixedAssetDepreciationRepository depreciationRepository;
    @Mock private AmortizationScheduleRepository amortizationScheduleRepository;
    @Mock private AmortizationEntryRepository amortizationEntryRepository;
    @Mock private AiSuggestionRepository aiSuggestionRepository;
    @Mock private FiscalPeriodService fiscalPeriodService;
    private ContinuousCloseService service;

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new ContinuousCloseService(fiscalPeriodRepository, invoiceRepository,
                purchaseBillRepository, fixedAssetRepository, depreciationRepository,
                amortizationScheduleRepository, amortizationEntryRepository,
                aiSuggestionRepository, fiscalPeriodService);
        TenantContext.setCurrentOrgId(orgId);
        // Default everything to "clean": no drafts, no assets/schedules, period open, nothing pending.
        when(invoiceRepository.countByOrgIdAndStatusAndIsDeletedFalseAndInvoiceDateBetween(any(), any(), any(), any()))
                .thenReturn(0L);
        when(purchaseBillRepository.countByOrgIdAndStatusAndIsDeletedFalseAndBillDateBetween(any(), any(), any(), any()))
                .thenReturn(0L);
        when(fixedAssetRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByAcquisitionDateAsc(orgId, "ACTIVE"))
                .thenReturn(List.of());
        when(amortizationScheduleRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtAsc(orgId, "ACTIVE"))
                .thenReturn(List.of());
        when(aiSuggestionRepository.countByOrgIdAndStatus(orgId, "PENDING")).thenReturn(0L);
        when(aiSuggestionRepository.existsOpenSuggestion(any(), any(), any(), any(), any(), any())).thenReturn(false);
        FiscalPeriod p = new FiscalPeriod();
        p.setId(UUID.randomUUID());
        p.setOrgId(orgId);
        p.setPeriodYear(2026);
        p.setPeriodMonth(5);
        p.setStatus("OPEN");
        when(fiscalPeriodRepository.findByOrgIdAndPeriodYearAndPeriodMonth(orgId, 2026, 5))
                .thenReturn(Optional.of(p));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private FixedAsset asset() {
        return FixedAsset.builder().id(UUID.randomUUID()).orgId(orgId).status("ACTIVE")
                .acquisitionDate(LocalDate.of(2026, 1, 1)).cost(new BigDecimal("1000"))
                .bookMethod("SLM").bookUsefulLifeMonths(12).build();
    }

    @Test
    void checklist_allClean_isReadyToClose() {
        Map<String, Object> r = service.checklist(2026, 5);
        assertEquals(true, r.get("readyToClose"));
        assertEquals(100, r.get("percentComplete"));
    }

    @Test
    void checklist_draftsAndMissingDepreciation_arePending() {
        when(invoiceRepository.countByOrgIdAndStatusAndIsDeletedFalseAndInvoiceDateBetween(any(), any(), any(), any()))
                .thenReturn(2L); // 2 draft invoices
        when(fixedAssetRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByAcquisitionDateAsc(orgId, "ACTIVE"))
                .thenReturn(List.of(asset()));
        when(depreciationRepository.existsByOrgIdAndPeriodYearAndPeriodMonth(orgId, 2026, 5))
                .thenReturn(false); // depreciation not run

        Map<String, Object> r = service.checklist(2026, 5);

        assertEquals(false, r.get("readyToClose"));
        assertTrue((int) r.get("percentComplete") < 100);
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> items = (List<Map<String, Object>>) r.get("items");
        assertEquals("PENDING", items.stream()
                .filter(i -> i.get("key").equals("invoices_posted")).findFirst().get().get("status"));
        assertEquals("PENDING", items.stream()
                .filter(i -> i.get("key").equals("depreciation")).findFirst().get().get("status"));
    }

    @Test
    void closeGuarded_notReadyWithoutForce_throws() {
        when(invoiceRepository.countByOrgIdAndStatusAndIsDeletedFalseAndInvoiceDateBetween(any(), any(), any(), any()))
                .thenReturn(1L); // a draft → not ready

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.closeGuarded(2026, 5, false));
        assertEquals("CLOSE_NOT_READY", ex.getErrorCode());
        verify(fiscalPeriodService, never()).closePeriod(anyInt(), anyInt());
    }

    @Test
    void closeGuarded_ready_closesPeriod() {
        Map<String, Object> r = service.closeGuarded(2026, 5, false);
        assertEquals(true, r.get("closed"));
        verify(fiscalPeriodService).closePeriod(2026, 5);
    }

    @Test
    void closeGuarded_notReadyButForced_closesAnyway() {
        when(purchaseBillRepository.countByOrgIdAndStatusAndIsDeletedFalseAndBillDateBetween(any(), any(), any(), any()))
                .thenReturn(3L); // drafts pending

        Map<String, Object> r = service.closeGuarded(2026, 5, true);
        assertEquals(true, r.get("closed"));
        assertEquals(true, r.get("forced"));
        verify(fiscalPeriodService).closePeriod(2026, 5);
    }
}
