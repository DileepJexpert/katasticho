package com.katasticho.erp.gst.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.gst.repository.EInvoiceRepository;
import com.katasticho.erp.gst.repository.EwayBillRepository;
import com.katasticho.erp.gst.repository.Gstr2bEntryRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class GstComplianceCalendarServiceTest {

    private final EwayBillRepository ewayBillRepository = mock(EwayBillRepository.class);
    private final Gstr2bEntryRepository gstr2bEntryRepository = mock(Gstr2bEntryRepository.class);
    private final EInvoiceRepository eInvoiceRepository = mock(EInvoiceRepository.class);
    private final CompositionService compositionService = mock(CompositionService.class);

    private final UUID orgId = UUID.randomUUID();

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private GstComplianceCalendarService serviceAt(String isoInstant) {
        TenantContext.setCurrentOrgId(orgId);
        Clock fixed = Clock.fixed(Instant.parse(isoInstant), ZoneOffset.UTC);
        return new GstComplianceCalendarService(
                ewayBillRepository, gstr2bEntryRepository, eInvoiceRepository,
                compositionService, fixed);
    }

    @Test
    void deadlinesGetCorrectStatusesEarlyInMonth() {
        // 2026-06-10: GSTR-1 for May due on the 11th (due soon), 3B on the 20th
        // (upcoming), TDS deposit was the 7th (overdue). 2B lands on the 14th,
        // so no recon item yet.
        GstComplianceCalendarService service = serviceAt("2026-06-10T06:00:00Z");
        when(ewayBillRepository.countByOrgIdAndStatusAndIsDeletedFalse(orgId, "PENDING")).thenReturn(0L);

        List<Map<String, Object>> items = service.calendar();

        Map<String, Object> gstr1 = byCode(items, "GSTR1");
        assertThat(gstr1.get("status")).isEqualTo("DUE_SOON");
        assertThat(gstr1.get("daysLeft")).isEqualTo(1L);
        assertThat(gstr1.get("period")).isEqualTo("2026-05");

        assertThat(byCode(items, "GSTR3B").get("status")).isEqualTo("UPCOMING");
        assertThat(byCode(items, "TDS_DEPOSIT").get("status")).isEqualTo("OVERDUE");
        // June → Q4 (Jan–Mar) of FY 2025-26 just ended, 26Q was due May 31.
        Map<String, Object> q26 = byCode(items, "TDS_RETURN_26Q");
        assertThat(q26.get("period")).isEqualTo("Q4 2025-26");
        assertThat(q26.get("status")).isEqualTo("OVERDUE");
        assertThat(items).noneMatch(m -> "GSTR2B_RECON".equals(m.get("code")));
        assertThat(items).noneMatch(m -> "EWAY_PENDING".equals(m.get("code")));
        assertThat(items).noneMatch(m -> "EINVOICE_PENDING".equals(m.get("code")));
    }

    @Test
    void after14thReconNudgeAppearsAndPendingEwbSurface() {
        GstComplianceCalendarService service = serviceAt("2026-06-15T06:00:00Z");
        when(gstr2bEntryRepository.countByOrgIdAndReturnPeriod(eq(orgId), anyString())).thenReturn(0L);
        when(ewayBillRepository.countByOrgIdAndStatusAndIsDeletedFalse(orgId, "PENDING")).thenReturn(3L);
        when(eInvoiceRepository.countByOrgIdAndStatusAndIsDeletedFalse(orgId, "PENDING")).thenReturn(2L);

        List<Map<String, Object>> items = service.calendar();

        Map<String, Object> recon = byCode(items, "GSTR2B_RECON");
        assertThat(recon.get("done")).isEqualTo(false);

        Map<String, Object> ewb = byCode(items, "EWAY_PENDING");
        assertThat(ewb.get("status")).isEqualTo("OVERDUE");
        assertThat(ewb.get("title").toString()).contains("3");

        Map<String, Object> einv = byCode(items, "EINVOICE_PENDING");
        assertThat(einv.get("title").toString()).contains("2");
    }

    @Test
    void compositionOrgSwapsMonthlyReturnsForCmp08AndGstr4() {
        GstComplianceCalendarService service = serviceAt("2026-06-15T06:00:00Z");
        when(compositionService.isEnabled(orgId)).thenReturn(true);
        when(ewayBillRepository.countByOrgIdAndStatusAndIsDeletedFalse(orgId, "PENDING")).thenReturn(0L);
        when(eInvoiceRepository.countByOrgIdAndStatusAndIsDeletedFalse(orgId, "PENDING")).thenReturn(0L);

        List<Map<String, Object>> items = service.calendar();

        // No regular-scheme returns or ITC recon for a composition dealer.
        assertThat(items).noneMatch(m -> "GSTR1".equals(m.get("code")));
        assertThat(items).noneMatch(m -> "GSTR3B".equals(m.get("code")));
        assertThat(items).noneMatch(m -> "GSTR2B_RECON".equals(m.get("code")));

        // June → quarter Jan–Mar ended 31 Mar; CMP-08 was due 18 Apr (overdue).
        Map<String, Object> cmp = byCode(items, "CMP08");
        assertThat(cmp.get("period").toString()).contains("2026-03-31");
        assertThat(cmp.get("dueDate").toString()).isEqualTo("2026-04-18");

        // FY 2025-26 GSTR-4 due 30 Apr 2026.
        Map<String, Object> gstr4 = byCode(items, "GSTR4");
        assertThat(gstr4.get("title").toString()).contains("2025-26");
        assertThat(gstr4.get("dueDate").toString()).isEqualTo("2026-04-30");

        // TDS items remain — composition doesn't change income-tax duties.
        assertThat(items).anyMatch(m -> "TDS_DEPOSIT".equals(m.get("code")));
    }

    private Map<String, Object> byCode(List<Map<String, Object>> items, String code) {
        return items.stream().filter(m -> code.equals(m.get("code"))).findFirst().orElseThrow();
    }
}
