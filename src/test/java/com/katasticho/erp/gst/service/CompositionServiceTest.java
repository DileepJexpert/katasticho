package com.katasticho.erp.gst.service;

import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.pos.repository.SalesReceiptRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class CompositionServiceTest {

    private final InvoiceRepository invoiceRepository = mock(InvoiceRepository.class);
    private final SalesReceiptRepository salesReceiptRepository = mock(SalesReceiptRepository.class);
    private final OrgSettingsService orgSettingsService = mock(OrgSettingsService.class);

    private final CompositionService service = new CompositionService(
            invoiceRepository, salesReceiptRepository, orgSettingsService);

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        when(orgSettingsService.get(orgId, CompositionService.SETTING_ENABLED, "false"))
                .thenReturn("true");
        when(orgSettingsService.get(orgId, CompositionService.SETTING_RATE, "1"))
                .thenReturn("1");
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void cmp08CombinesInvoiceAndPosTurnoverAtFlatRate() {
        // Q1 FY 2026-27 = Apr 1 – Jun 30 2026, CMP-08 due Jul 18.
        when(invoiceRepository.sumPostedTotalByOrgAndDateRange(
                eq(orgId), eq(LocalDate.of(2026, 4, 1)), eq(LocalDate.of(2026, 6, 30))))
                .thenReturn(new BigDecimal("300000"));
        when(salesReceiptRepository.sumActiveTotalByOrgAndDateRange(
                eq(orgId), eq(LocalDate.of(2026, 4, 1)), eq(LocalDate.of(2026, 6, 30))))
                .thenReturn(new BigDecimal("200000"));

        Map<String, Object> cmp = service.cmp08(2026, 1);

        assertThat(cmp.get("quarter")).isEqualTo("Q1");
        assertThat(cmp.get("dueDate")).isEqualTo(LocalDate.of(2026, 7, 18));
        assertThat((BigDecimal) cmp.get("totalTurnover")).isEqualByComparingTo("500000");
        // 1% of 5L = 5000, split 2500 CGST + 2500 SGST
        assertThat((BigDecimal) cmp.get("taxPayable")).isEqualByComparingTo("5000");
        assertThat((BigDecimal) cmp.get("cgst")).isEqualByComparingTo("2500");
        assertThat((BigDecimal) cmp.get("sgst")).isEqualByComparingTo("2500");
    }

    @Test
    void restaurantRateApplies() {
        when(orgSettingsService.get(orgId, CompositionService.SETTING_RATE, "1"))
                .thenReturn("5");
        when(invoiceRepository.sumPostedTotalByOrgAndDateRange(eq(orgId),
                eq(LocalDate.of(2026, 7, 1)), eq(LocalDate.of(2026, 9, 30))))
                .thenReturn(new BigDecimal("100000"));
        when(salesReceiptRepository.sumActiveTotalByOrgAndDateRange(eq(orgId),
                eq(LocalDate.of(2026, 7, 1)), eq(LocalDate.of(2026, 9, 30))))
                .thenReturn(BigDecimal.ZERO);

        Map<String, Object> cmp = service.cmp08(2026, 2);

        assertThat((BigDecimal) cmp.get("taxPayable")).isEqualByComparingTo("5000");
    }

    @Test
    void q4SpansIntoNextCalendarYear() {
        when(invoiceRepository.sumPostedTotalByOrgAndDateRange(eq(orgId),
                eq(LocalDate.of(2027, 1, 1)), eq(LocalDate.of(2027, 3, 31))))
                .thenReturn(BigDecimal.ZERO);
        when(salesReceiptRepository.sumActiveTotalByOrgAndDateRange(eq(orgId),
                eq(LocalDate.of(2027, 1, 1)), eq(LocalDate.of(2027, 3, 31))))
                .thenReturn(BigDecimal.ZERO);

        Map<String, Object> cmp = service.cmp08(2026, 4);

        assertThat(cmp.get("periodFrom")).isEqualTo(LocalDate.of(2027, 1, 1));
        assertThat(cmp.get("dueDate")).isEqualTo(LocalDate.of(2027, 4, 18));
    }

    @Test
    void rejectsBadQuarter() {
        assertThatThrownBy(() -> service.cmp08(2026, 5))
                .hasMessageContaining("Quarter must be 1-4");
    }
}
