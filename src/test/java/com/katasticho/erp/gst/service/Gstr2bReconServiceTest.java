package com.katasticho.erp.gst.service;

import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.service.AiSuggestionService;
import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.gst.entity.Gstr2bEntry;
import com.katasticho.erp.gst.repository.Gstr2bEntryRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class Gstr2bReconServiceTest {

    private final Gstr2bEntryRepository entryRepository = mock(Gstr2bEntryRepository.class);
    private final PurchaseBillRepository purchaseBillRepository = mock(PurchaseBillRepository.class);
    private final ContactRepository contactRepository = mock(ContactRepository.class);
    private final AiSuggestionService aiSuggestionService = mock(AiSuggestionService.class);
    private final GspClient gspClient = mock(GspClient.class);
    private final com.katasticho.erp.gst.repository.GstFilingSnapshotRepository filingSnapshotRepository =
            mock(com.katasticho.erp.gst.repository.GstFilingSnapshotRepository.class);

    private final Gstr2bReconService service = new Gstr2bReconService(
            entryRepository, purchaseBillRepository, contactRepository, aiSuggestionService, gspClient,
            filingSnapshotRepository, new Gstr2aParser());

    private final UUID orgId = UUID.randomUUID();
    private final UUID vendorId = UUID.randomUUID();
    private final AtomicReference<List<Gstr2bEntry>> savedRef = new AtomicReference<>(List.of());

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        when(entryRepository.saveAll(any())).thenAnswer(inv -> {
            List<Gstr2bEntry> list = new ArrayList<>();
            for (Object o : (Iterable<?>) inv.getArgument(0)) {
                Gstr2bEntry e = (Gstr2bEntry) o;
                if (e.getId() == null) e.setId(UUID.randomUUID());
                list.add(e);
            }
            savedRef.set(list);
            return list;
        });
        when(entryRepository.findByOrgIdAndReturnPeriodOrderBySupplierGstinAscInvoiceNumberAsc(
                eq(orgId), anyString())).thenAnswer(inv -> savedRef.get());
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void parsesPortalJsonB2bSection() {
        Map<String, Object> portal = Map.of("data", Map.of("docdata", Map.of("b2b", List.of(
                Map.of(
                        "ctin", "27AABCT1234A1Z5",
                        "trdnm", "ABC Pharma",
                        "inv", List.of(Map.of(
                                "inum", "INV-001",
                                "dt", "05-05-2026",
                                "val", 1064,
                                "itcavl", "Y",
                                "itms", List.of(Map.of(
                                        "rt", 12, "txval", 950, "igst", 0, "cgst", 57, "sgst", 57))
                        ))
                )))));

        List<Gstr2bEntry> parsed = service.parsePortalJson(orgId, "2026-05", portal);

        assertThat(parsed).hasSize(1);
        Gstr2bEntry e = parsed.get(0);
        assertThat(e.getSupplierGstin()).isEqualTo("27AABCT1234A1Z5");
        assertThat(e.getInvoiceNumber()).isEqualTo("INV-001");
        assertThat(e.getInvoiceDate()).isEqualTo(LocalDate.of(2026, 5, 5));
        assertThat(e.getInvoiceValue()).isEqualByComparingTo("1064");
        assertThat(e.getTaxableValue()).isEqualByComparingTo("950");
        assertThat(e.getCgst()).isEqualByComparingTo("57");
        assertThat(e.totalTax()).isEqualByComparingTo("114");
    }

    @Test
    void uploadMatchesMismatchesAndFlagsMissing() {
        Contact vendor = Contact.builder()
                .contactType(ContactType.VENDOR)
                .displayName("ABC Pharma")
                .gstin("27AABCT1234A1Z5")
                .build();
        vendor.setId(vendorId);
        when(contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), any()))
                .thenReturn(List.of(vendor));

        PurchaseBill matchedBill = bill("INV-001", new BigDecimal("1064"));
        PurchaseBill mismatchBill = bill("INV-003", new BigDecimal("5000"));
        PurchaseBill unfiledBill = bill("INV-XYZ", new BigDecimal("2000"));
        when(purchaseBillRepository.findPostedByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(List.of(matchedBill, mismatchBill, unfiledBill));

        Map<String, Object> portal = Map.of("entries", List.of(
                entry("INV-001", "1064"),   // exact → MATCHED
                entry("inv 003", "6000"),   // found but value differs → VALUE_MISMATCH
                entry("INV-002", "750")     // not recorded → NOT_IN_BOOKS
        ));

        Map<String, Object> summary = service.upload("2026-05", portal);

        assertThat(summary.get("matched")).isEqualTo(1L);
        assertThat(summary.get("valueMismatch")).isEqualTo(1L);
        assertThat(summary.get("notInBooks")).isEqualTo(1L);

        List<Gstr2bEntry> saved = savedRef.get();
        assertThat(saved).extracting(Gstr2bEntry::getMatchStatus)
                .containsExactlyInAnyOrder("MATCHED", "VALUE_MISMATCH", "NOT_IN_BOOKS");

        // Mismatch + missing each create an inbox suggestion; matched does not.
        ArgumentCaptor<AiSuggestion> captor = ArgumentCaptor.forClass(AiSuggestion.class);
        verify(aiSuggestionService, times(2)).createSuggestion(captor.capture());
        assertThat(captor.getAllValues()).extracting(AiSuggestion::getSuggestionType)
                .containsExactlyInAnyOrder("GSTR2B_VALUE_MISMATCH", "GSTR2B_MISSING_BILL");

        // The bill whose supplier never filed shows up as ITC at risk.
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> notFiled = (List<Map<String, Object>>) summary.get("supplierNotFiled");
        assertThat(notFiled).extracting(m -> m.get("vendorBillNumber")).contains("INV-XYZ");
        assertThat((BigDecimal) summary.get("itcAtRisk")).isPositive();
    }

    @Test
    void fetchAndReconcile_noGsp_throws() {
        when(gspClient.isConfigured(orgId)).thenReturn(false);

        assertThatThrownBy(() -> service.fetchAndReconcile("2026-05"))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode())
                .isEqualTo("GSP_NOT_CONFIGURED");
        verify(gspClient, never()).fetchGstr2b(any(), anyString());
    }

    @Test
    void fetchAndReconcile_pullsFromGspWithPortalPeriodAndReconciles() {
        when(gspClient.isConfigured(orgId)).thenReturn(true);
        when(purchaseBillRepository.findPostedByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(List.of());
        Map<String, Object> portal = Map.of("entries", List.of(entry("INV-009", "1180")));
        // GSP must be asked for the MMYYYY return period derived from 2026-05.
        when(gspClient.fetchGstr2b(orgId, "052026")).thenReturn(portal);

        Map<String, Object> summary = service.fetchAndReconcile("2026-05");

        verify(gspClient).fetchGstr2b(orgId, "052026");
        assertThat(summary.get("period")).isEqualTo("2026-05");
        assertThat(summary.get("notInBooks")).isEqualTo(1L); // no books → unmatched
    }

    @Test
    @SuppressWarnings("unchecked")
    void reUploadClearsPriorPendingSuggestionsForPeriod() {
        when(contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), any()))
                .thenReturn(List.of());
        when(purchaseBillRepository.findPostedByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(List.of());

        Map<String, Object> portal = Map.of("entries", List.of(entry("INV-100", "5000")));

        // First upload: no prior entries for the period -> nothing to dismiss.
        service.upload("2026-05", portal);
        verify(aiSuggestionService, never()).dismissPendingForEntities(anyString(), any());

        List<UUID> firstIds = savedRef.get().stream().map(Gstr2bEntry::getId).toList();

        // Re-upload same period: the prior upload's entries are dismissed before
        // being replaced, so the inbox doesn't accumulate duplicate suggestions.
        service.upload("2026-05", portal);

        ArgumentCaptor<Collection<UUID>> ids = ArgumentCaptor.forClass(Collection.class);
        verify(aiSuggestionService).dismissPendingForEntities(eq("GSTR2B_ENTRY"), ids.capture());
        assertThat(ids.getValue()).containsExactlyInAnyOrderElementsOf(firstIds);
    }

    @Test
    void reUploadPreservesPriorImsActionForSameInvoice() {
        when(contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), any()))
                .thenReturn(List.of());
        when(purchaseBillRepository.findPostedByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(List.of());

        // First upload of one supplier invoice.
        Map<String, Object> portal = Map.of("entries", List.of(entry("INV-200", "5000")));
        service.upload("2026-05", portal);

        // Simulate an IMS Section-38 ACCEPT decision recorded on the saved row.
        UUID actor = UUID.randomUUID();
        Gstr2bEntry actioned = savedRef.get().get(0);
        actioned.setImsAction("ACCEPT");
        actioned.setImsRemarks("Verified against GRN");
        actioned.setImsActionBy(actor);

        // Re-upload the SAME period (portal JSON carries NO IMS fields) with the
        // same supplier invoice PLUS a brand-new one.
        Map<String, Object> reupload = Map.of("entries",
                List.of(entry("INV-200", "5000"), entry("INV-201", "3000")));
        service.upload("2026-05", reupload);

        List<Gstr2bEntry> after = savedRef.get();
        Gstr2bEntry preserved = after.stream()
                .filter(e -> "INV-200".equals(e.getInvoiceNumber())).findFirst().orElseThrow();
        Gstr2bEntry fresh = after.stream()
                .filter(e -> "INV-201".equals(e.getInvoiceNumber())).findFirst().orElseThrow();

        // The prior IMS decision is carried onto the re-parsed row, not wiped.
        assertThat(preserved.getImsAction()).isEqualTo("ACCEPT");
        assertThat(preserved.getImsRemarks()).isEqualTo("Verified against GRN");
        assertThat(preserved.getImsActionBy()).isEqualTo(actor);
        // A new invoice starts with no IMS action.
        assertThat(fresh.getImsAction()).isNull();
    }

    @Test
    void matchKeyNormalizesNumberAndCase() {
        assertThat(Gstr2bReconService.matchKey("27X", "INV-001"))
                .isEqualTo(Gstr2bReconService.matchKey("27x", "inv/001"));
        assertThat(Gstr2bReconService.matchKey("27X", "0042"))
                .isEqualTo(Gstr2bReconService.matchKey("27X", "42"));
    }

    private PurchaseBill bill(String vendorBillNumber, BigDecimal total) {
        return PurchaseBill.builder()
                .id(UUID.randomUUID())
                .contactId(vendorId)
                .billNumber("BILL-" + vendorBillNumber)
                .vendorBillNumber(vendorBillNumber)
                .billDate(LocalDate.of(2026, 5, 10))
                .totalAmount(total)
                .taxAmount(new BigDecimal("114"))
                .status("OPEN")
                .build();
    }

    private Map<String, Object> entry(String invoiceNumber, String value) {
        return Map.of(
                "supplierGstin", "27AABCT1234A1Z5",
                "supplierName", "ABC Pharma",
                "invoiceNumber", invoiceNumber,
                "invoiceValue", value,
                "taxableValue", "950",
                "cgst", "57",
                "sgst", "57"
        );
    }

    // ── GSP auto-fetch ──

    @Test
    void fetchFromGsp_notConfigured_throwsGspNotConfigured() {
        when(gspClient.isConfigured(orgId)).thenReturn(false);

        BusinessException ex = org.junit.jupiter.api.Assertions.assertThrows(
                BusinessException.class, () -> service.fetchFromGsp("2026-05"));

        assertThat(ex.getErrorCode()).isEqualTo("GSP_NOT_CONFIGURED");
        verify(gspClient, never()).fetch2b(any(), anyString());
        verify(entryRepository, never()).saveAll(any());
    }

    @Test
    void fetchFromGsp_configured_fetchesFromGspAndReconciles() {
        when(gspClient.isConfigured(orgId)).thenReturn(true);
        // Aggregator returns the same shape as the portal-uploaded JSON.
        Map<String, Object> portalJson = Map.of("data", Map.of("docdata", Map.of("b2b", List.of(
                Map.of("ctin", "27AABCT1234A1Z5", "trdnm", "ABC Pharma", "inv", List.of(
                        Map.of("inum", "INV-101", "val", "1064", "txval", "950", "tx", List.of(
                                Map.of("cgst", "57", "sgst", "57")))))))));
        when(gspClient.fetch2b(eq(orgId), eq("2026-05"))).thenReturn(portalJson);
        when(purchaseBillRepository.findPostedByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(List.of());
        when(contactRepository.findAllById(any())).thenReturn(List.of());

        Map<String, Object> summary = service.fetchFromGsp("2026-05");

        verify(gspClient).fetch2b(orgId, "2026-05");
        verify(entryRepository, org.mockito.Mockito.atLeastOnce()).saveAll(any());
        assertThat(summary).isNotNull();
    }

    @Test
    void fetchFromGsp_emptyResponse_throwsGst2bEmpty() {
        when(gspClient.isConfigured(orgId)).thenReturn(true);
        when(gspClient.fetch2b(eq(orgId), eq("2026-05"))).thenReturn(Map.of());

        BusinessException ex = org.junit.jupiter.api.Assertions.assertThrows(
                BusinessException.class, () -> service.fetchFromGsp("2026-05"));

        assertThat(ex.getErrorCode()).isEqualTo("GST_2B_EMPTY");
    }
}
