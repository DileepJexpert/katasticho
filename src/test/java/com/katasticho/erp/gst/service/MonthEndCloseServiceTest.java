package com.katasticho.erp.gst.service;

import com.katasticho.erp.accounting.entity.FiscalPeriod;
import com.katasticho.erp.accounting.repository.FiscalPeriodRepository;
import com.katasticho.erp.common.context.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MonthEndCloseServiceTest {

    @Mock private ImsService imsService;
    @Mock private Gst20RateRemapper rateRemapper;
    @Mock private FiscalPeriodRepository fiscalPeriodRepository;

    private MonthEndCloseService service;
    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new MonthEndCloseService(imsService, rateRemapper, fiscalPeriodRepository);
        TenantContext.setCurrentOrgId(orgId);
    }

    @AfterEach
    void clear() { TenantContext.clear(); }

    @Test
    void all_clean_returns_overall_READY_and_closable() {
        when(imsService.periodSummary("2026-06")).thenReturn(
                summary(10, 0, 10, 0, 0, BigDecimal.ZERO));
        when(rateRemapper.candidates()).thenReturn(driftCandidates(0));
        when(fiscalPeriodRepository.findByOrgIdAndPeriodYearAndPeriodMonth(orgId, 2026, 6))
                .thenReturn(Optional.empty());

        Map<String, Object> out = service.checklist(2026, 6);
        assertEquals("READY", out.get("overallStatus"));
        assertEquals(true, out.get("closable"));
    }

    @Test
    void ims_no_action_blocks_closure() {
        when(imsService.periodSummary("2026-06")).thenReturn(
                summary(10, 3, 5, 1, 1, new BigDecimal("18000")));
        when(rateRemapper.candidates()).thenReturn(driftCandidates(0));
        when(fiscalPeriodRepository.findByOrgIdAndPeriodYearAndPeriodMonth(orgId, 2026, 6))
                .thenReturn(Optional.empty());

        Map<String, Object> out = service.checklist(2026, 6);
        assertEquals("BLOCKED", out.get("overallStatus"));
        assertEquals(false, out.get("closable"));

        @SuppressWarnings("unchecked")
        List<MonthEndCloseService.ChecklistItem> items =
                (List<MonthEndCloseService.ChecklistItem>) out.get("items");
        var ims = items.stream().filter(i -> "ims".equals(i.id())).findFirst().orElseThrow();
        assertEquals("BLOCKED", ims.status());
        assertTrue(ims.summary().contains("18000"));
        var gstr3b = items.stream().filter(i -> "gstr-3b".equals(i.id())).findFirst().orElseThrow();
        assertEquals("BLOCKED", gstr3b.status(),
                "3B can't finalise while IMS rows are unactioned");
    }

    @Test
    void rate_drift_marks_attention_but_does_not_block() {
        when(imsService.periodSummary("2026-06")).thenReturn(
                summary(10, 0, 10, 0, 0, BigDecimal.ZERO));
        when(rateRemapper.candidates()).thenReturn(driftCandidates(1427));
        when(fiscalPeriodRepository.findByOrgIdAndPeriodYearAndPeriodMonth(orgId, 2026, 6))
                .thenReturn(Optional.empty());

        Map<String, Object> out = service.checklist(2026, 6);
        assertEquals("NEEDS_ATTENTION", out.get("overallStatus"));
        assertEquals(true, out.get("closable"));

        @SuppressWarnings("unchecked")
        List<MonthEndCloseService.ChecklistItem> items =
                (List<MonthEndCloseService.ChecklistItem>) out.get("items");
        var remap = items.stream().filter(i -> "gst-20-remap".equals(i.id())).findFirst().orElseThrow();
        assertEquals("NEEDS_ATTENTION", remap.status());
        assertTrue(remap.summary().contains("1427"));
    }

    @Test
    void open_fiscal_period_is_NEEDS_ATTENTION_not_blocking() {
        when(imsService.periodSummary("2026-06")).thenReturn(
                summary(10, 0, 10, 0, 0, BigDecimal.ZERO));
        when(rateRemapper.candidates()).thenReturn(driftCandidates(0));
        FiscalPeriod fp = new FiscalPeriod();
        fp.setStatus("OPEN");
        when(fiscalPeriodRepository.findByOrgIdAndPeriodYearAndPeriodMonth(orgId, 2026, 6))
                .thenReturn(Optional.of(fp));

        Map<String, Object> out = service.checklist(2026, 6);
        assertEquals("NEEDS_ATTENTION", out.get("overallStatus"));
        assertEquals(true, out.get("closable"));
    }

    @Test
    void closed_fiscal_period_is_READY() {
        when(imsService.periodSummary("2026-06")).thenReturn(
                summary(10, 0, 10, 0, 0, BigDecimal.ZERO));
        when(rateRemapper.candidates()).thenReturn(driftCandidates(0));
        FiscalPeriod fp = new FiscalPeriod();
        fp.setStatus("CLOSED");
        when(fiscalPeriodRepository.findByOrgIdAndPeriodYearAndPeriodMonth(orgId, 2026, 6))
                .thenReturn(Optional.of(fp));

        Map<String, Object> out = service.checklist(2026, 6);
        assertEquals("READY", out.get("overallStatus"));
    }

    @Test
    void rejected_pending_rows_flag_2b_recon_for_attention() {
        when(imsService.periodSummary("2026-06")).thenReturn(
                summary(10, 0, 5, 3, 2, BigDecimal.ZERO));
        when(rateRemapper.candidates()).thenReturn(driftCandidates(0));
        when(fiscalPeriodRepository.findByOrgIdAndPeriodYearAndPeriodMonth(orgId, 2026, 6))
                .thenReturn(Optional.empty());

        Map<String, Object> out = service.checklist(2026, 6);
        @SuppressWarnings("unchecked")
        List<MonthEndCloseService.ChecklistItem> items =
                (List<MonthEndCloseService.ChecklistItem>) out.get("items");
        var recon = items.stream().filter(i -> "2b-recon".equals(i.id())).findFirst().orElseThrow();
        assertEquals("NEEDS_ATTENTION", recon.status());
        assertTrue(recon.summary().contains("5"), "rejected+pending = 5");
    }

    @Test
    void empty_period_returns_ready_with_zero_total_message() {
        when(imsService.periodSummary("2026-06")).thenReturn(
                summary(0, 0, 0, 0, 0, BigDecimal.ZERO));
        when(rateRemapper.candidates()).thenReturn(driftCandidates(0));
        when(fiscalPeriodRepository.findByOrgIdAndPeriodYearAndPeriodMonth(orgId, 2026, 6))
                .thenReturn(Optional.empty());

        Map<String, Object> out = service.checklist(2026, 6);
        assertEquals("READY", out.get("overallStatus"));
    }

    // ── helpers ───────────────────────────────────────────────────

    private Map<String, Object> summary(long total, long noAction, long accepted,
                                        long rejected, long pending, BigDecimal exposure) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("totalRows", total);
        m.put("noAction", noAction);
        m.put("accepted", accepted);
        m.put("rejected", rejected);
        m.put("pending", pending);
        m.put("deemedAcceptedItcExposure", exposure);
        return m;
    }

    private Map<String, Object> driftCandidates(int total) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("totalDriftItems", total);
        m.put("bucketCount", total == 0 ? 0 : 2);
        m.put("buckets", List.of());
        return m;
    }
}
