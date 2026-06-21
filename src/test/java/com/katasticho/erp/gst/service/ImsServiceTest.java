package com.katasticho.erp.gst.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.gst.entity.Gstr2bEntry;
import com.katasticho.erp.gst.repository.Gstr2bEntryRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ImsServiceTest {

    @Mock private Gstr2bEntryRepository entryRepository;
    private ImsService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new ImsService(entryRepository);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void clear() { TenantContext.clear(); }

    // ── Single action ────────────────────────────────────────────

    @Test
    void action_records_who_and_when_and_what() {
        Gstr2bEntry e = entry("UNMATCHED", "100", "100");
        when(entryRepository.findByIdAndOrgId(e.getId(), orgId)).thenReturn(Optional.of(e));
        when(entryRepository.save(any())).thenAnswer(i -> i.getArgument(0));

        Gstr2bEntry actioned = service.action(e.getId(), "ACCEPT", "Looks correct");
        assertEquals("ACCEPT", actioned.getImsAction());
        assertEquals(userId, actioned.getImsActionBy());
        assertNotNull(actioned.getImsActionAt());
        assertEquals("Looks correct", actioned.getImsRemarks());
    }

    @Test
    void invalid_action_throws_with_clear_code() {
        Gstr2bEntry e = entry("MATCHED", "100", "100");
        var ex = assertThrows(BusinessException.class,
                () -> service.action(e.getId(), "MAYBE", "?"));
        assertEquals("IMS_INVALID_ACTION", ex.getErrorCode());
    }

    @Test
    void null_action_throws() {
        Gstr2bEntry e = entry("MATCHED", "100", "100");
        var ex = assertThrows(BusinessException.class,
                () -> service.action(e.getId(), null, null));
        assertEquals("IMS_ACTION_REQUIRED", ex.getErrorCode());
    }

    @Test
    void unknown_entry_throws_not_found() {
        UUID missing = UUID.randomUUID();
        when(entryRepository.findByIdAndOrgId(missing, orgId)).thenReturn(Optional.empty());
        assertThrows(BusinessException.class,
                () -> service.action(missing, "ACCEPT", null));
    }

    // ── Bulk action ──────────────────────────────────────────────

    @Test
    void bulk_action_processes_all_rows_returns_counters() {
        Gstr2bEntry a = entry("MATCHED", "100", "100");
        Gstr2bEntry b = entry("MATCHED", "200", "200");
        when(entryRepository.findByIdAndOrgId(a.getId(), orgId)).thenReturn(Optional.of(a));
        when(entryRepository.findByIdAndOrgId(b.getId(), orgId)).thenReturn(Optional.of(b));
        when(entryRepository.save(any())).thenAnswer(i -> i.getArgument(0));

        var out = service.bulkAction(List.of(a.getId(), b.getId()), "ACCEPT", "Bulk accept");
        assertEquals(2, out.get("ok"));
        assertEquals(0, out.get("skipped"));
    }

    @Test
    void bulk_action_skips_missing_rows_instead_of_throwing() {
        Gstr2bEntry a = entry("MATCHED", "100", "100");
        UUID missing = UUID.randomUUID();
        when(entryRepository.findByIdAndOrgId(a.getId(), orgId)).thenReturn(Optional.of(a));
        when(entryRepository.findByIdAndOrgId(missing, orgId)).thenReturn(Optional.empty());
        when(entryRepository.save(any())).thenAnswer(i -> i.getArgument(0));

        var out = service.bulkAction(List.of(a.getId(), missing), "ACCEPT", null);
        assertEquals(1, out.get("ok"));
        assertEquals(1, out.get("skipped"));
    }

    @Test
    void empty_bulk_throws() {
        var ex = assertThrows(BusinessException.class,
                () -> service.bulkAction(List.of(), "ACCEPT", null));
        assertEquals("IMS_NO_ROWS_SELECTED", ex.getErrorCode());
    }

    // ── AI recommendation rules ──────────────────────────────────

    @Test
    void recommends_accept_for_matched_rows() {
        var r = service.recommendOne(entry("MATCHED", "100", "100"));
        assertEquals("ACCEPT", r.action());
        assertTrue(r.reason().toLowerCase().contains("match"));
    }

    @Test
    void recommends_reject_for_value_mismatch() {
        var r = service.recommendOne(entry("VALUE_MISMATCH", "100", "150"));
        assertEquals("REJECT", r.action());
        assertTrue(r.reason().toLowerCase().contains("differ")
                || r.reason().toLowerCase().contains("mismatch")
                || r.reason().toLowerCase().contains("revis"));
    }

    @Test
    void recommends_pending_for_not_in_books() {
        var r = service.recommendOne(entry("NOT_IN_BOOKS", "100", "100"));
        assertEquals("PENDING", r.action());
        assertTrue(r.reason().toLowerCase().contains("no purchase bill"));
    }

    @Test
    void recommends_pending_for_unknown_match_status() {
        var r = service.recommendOne(entry("WEIRD_NEW_STATUS", "100", "100"));
        assertEquals("PENDING", r.action());
        assertTrue(r.reason().toLowerCase().contains("human"));
    }

    @Test
    void recommendForPeriod_skips_already_actioned_rows() {
        Gstr2bEntry a = entry("MATCHED", "100", "100");
        a.setImsAction("ACCEPT"); // already acted
        Gstr2bEntry b = entry("MATCHED", "200", "200");
        when(entryRepository.findByOrgIdAndReturnPeriodOrderBySupplierGstinAscInvoiceNumberAsc(
                orgId, "2026-06")).thenReturn(List.of(a, b));
        when(entryRepository.save(any())).thenAnswer(i -> i.getArgument(0));

        var out = service.recommendForPeriod("2026-06");
        assertEquals(1, out.get("acceptedRecommendations"));
        assertNull(a.getImsAiRecommendation(), "must not overwrite actioned row");
        assertEquals("ACCEPT", b.getImsAiRecommendation());
    }

    @Test
    void applyAllAiRecommendations_only_applies_rows_with_a_suggestion() {
        Gstr2bEntry recommended = entry("MATCHED", "100", "100");
        recommended.setImsAiRecommendation("ACCEPT");
        recommended.setImsAiReason("Matched");
        Gstr2bEntry noRec = entry("UNMATCHED", "200", "200");
        when(entryRepository.findByOrgIdAndReturnPeriodAndImsActionIsNullOrderBySupplierGstinAsc(
                orgId, "2026-06")).thenReturn(List.of(recommended, noRec));
        when(entryRepository.save(any())).thenAnswer(i -> i.getArgument(0));

        var out = service.applyAllAiRecommendations("2026-06");
        assertEquals(1, out.get("applied"));
        assertEquals(1, out.get("skippedNoRecommendation"));
        assertEquals("ACCEPT", recommended.getImsAction());
    }

    // ── Period summary ───────────────────────────────────────────

    @Test
    void summary_quantifies_deemed_accepted_itc_exposure() {
        // 3 no-action rows with total tax 36 (CGST 9 + SGST 9 in each of two; IGST 18 in one)
        Gstr2bEntry a = entryWithTax("MATCHED", "9", "9", "0");
        Gstr2bEntry b = entryWithTax("MATCHED", "9", "9", "0");
        Gstr2bEntry c = entryWithTax("NOT_IN_BOOKS", "0", "0", "18");
        when(entryRepository.countByOrgIdAndReturnPeriod(orgId, "2026-06")).thenReturn(3L);
        when(entryRepository.countByOrgIdAndReturnPeriodAndImsActionIsNull(orgId, "2026-06"))
                .thenReturn(3L);
        when(entryRepository.countByOrgIdAndReturnPeriodAndImsAction(orgId, "2026-06", "ACCEPT"))
                .thenReturn(0L);
        when(entryRepository.countByOrgIdAndReturnPeriodAndImsAction(orgId, "2026-06", "REJECT"))
                .thenReturn(0L);
        when(entryRepository.countByOrgIdAndReturnPeriodAndImsAction(orgId, "2026-06", "PENDING"))
                .thenReturn(0L);
        when(entryRepository.findByOrgIdAndReturnPeriodAndImsActionIsNullOrderBySupplierGstinAsc(
                orgId, "2026-06")).thenReturn(List.of(a, b, c));

        Map<String, Object> summary = service.periodSummary("2026-06");
        assertEquals(3L, summary.get("totalRows"));
        assertEquals(3L, summary.get("noAction"));
        assertEquals(0, new BigDecimal("54")
                .compareTo((BigDecimal) summary.get("deemedAcceptedItcExposure")));
        assertNotNull(summary.get("warning"));
    }

    // ── helpers ───────────────────────────────────────────────────

    private Gstr2bEntry entry(String matchStatus, String taxable, String tax) {
        Gstr2bEntry e = new Gstr2bEntry();
        e.setId(UUID.randomUUID());
        e.setOrgId(orgId);
        e.setReturnPeriod("2026-06");
        e.setSupplierGstin("27ABCDE1234F1Z5");
        e.setInvoiceNumber("INV-001");
        e.setTaxableValue(new BigDecimal(taxable));
        e.setIgst(new BigDecimal(tax));
        e.setCgst(BigDecimal.ZERO);
        e.setSgst(BigDecimal.ZERO);
        e.setCess(BigDecimal.ZERO);
        e.setInvoiceValue(new BigDecimal(taxable).add(new BigDecimal(tax)));
        e.setMatchStatus(matchStatus);
        return e;
    }

    private Gstr2bEntry entryWithTax(String matchStatus, String cgst, String sgst, String igst) {
        Gstr2bEntry e = entry(matchStatus, "100", "0");
        e.setCgst(new BigDecimal(cgst));
        e.setSgst(new BigDecimal(sgst));
        e.setIgst(new BigDecimal(igst));
        return e;
    }
}
