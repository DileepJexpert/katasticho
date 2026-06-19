package com.katasticho.erp.gst.service;

import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.ai.service.AiSuggestionService;
import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.gst.dto.ItcRiskDtos.ItcRiskReport;
import com.katasticho.erp.gst.entity.Gstr2bEntry;
import com.katasticho.erp.gst.repository.Gstr2bEntryRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ItcRiskMonitorServiceTest {

    @Mock private PurchaseBillRepository purchaseBillRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private Gstr2bEntryRepository entryRepository;
    @Mock private AiSuggestionService aiSuggestionService;
    @Mock private AiSuggestionRepository aiSuggestionRepository;
    @Mock private GspClient gspClient;
    @Mock private Gstr2bReconService gstr2bReconService;
    @Mock private com.katasticho.erp.gst.repository.GstFilingSnapshotRepository filingSnapshotRepository;
    private ItcRiskMonitorService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID filerId = UUID.randomUUID();
    private final UUID laggardId = UUID.randomUUID();
    private final UUID unregId = UUID.randomUUID();

    // Fixed at 2026-06-08 → 3 days before the 2026-05 filing deadline (11th) → CRITICAL.
    private final java.time.Clock clock = java.time.Clock.fixed(
            java.time.Instant.parse("2026-06-08T10:00:00Z"), java.time.ZoneOffset.UTC);

    @BeforeEach
    void setUp() {
        service = new ItcRiskMonitorService(purchaseBillRepository, contactRepository,
                entryRepository, aiSuggestionService, aiSuggestionRepository, gspClient, gstr2bReconService,
                filingSnapshotRepository, clock);
        TenantContext.setCurrentOrgId(orgId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private Contact vendor(UUID id, String name, String gstin, String mobile) {
        Contact c = Contact.builder().displayName(name).gstin(gstin).mobile(mobile).build();
        c.setId(id);
        return c;
    }

    private PurchaseBill bill(UUID contactId, String vendorBillNo, String tax) {
        return PurchaseBill.builder().id(UUID.randomUUID()).orgId(orgId)
                .contactId(contactId).vendorBillNumber(vendorBillNo)
                .taxAmount(new BigDecimal(tax)).build();
    }

    private Gstr2bEntry filed(String gstin, String invNo) {
        return Gstr2bEntry.builder().orgId(orgId).returnPeriod("2026-05")
                .supplierGstin(gstin).invoiceNumber(invNo)
                .igst(new BigDecimal("100")).build();
    }

    @Test
    void assess_noFilingData_returnsUnavailableAndFlagsNobody() {
        when(entryRepository.findByOrgIdAndReturnPeriodOrderBySupplierGstinAscInvoiceNumberAsc(orgId, "2026-05"))
                .thenReturn(List.of());

        ItcRiskReport r = service.assessRisk("2026-05");

        assertThat(r.dataAvailable()).isFalse();
        assertThat(r.suppliers()).isEmpty();
        assertThat(r.message()).contains("No filing data");
        verifyNoInteractions(purchaseBillRepository); // doesn't even look at books — no false alarms
    }

    @Test
    void assess_flagsUnfiledRegisteredSupplierOnly() {
        // Filer reported INV-1; laggard did not report INV-9; unreg has no GSTIN.
        when(entryRepository.findByOrgIdAndReturnPeriodOrderBySupplierGstinAscInvoiceNumberAsc(orgId, "2026-05"))
                .thenReturn(List.of(filed("27AAAAA0000A1Z5", "INV-1")));
        when(purchaseBillRepository.findPostedByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(List.of(
                        bill(filerId, "INV-1", "500"),     // already filed → safe
                        bill(laggardId, "INV-9", "4000"),  // not filed → at risk
                        bill(laggardId, "INV-10", "1500"), // same laggard, second invoice
                        bill(unregId, "CASH-1", "200")));  // unregistered → ignored
        when(contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), any()))
                .thenReturn(List.of(
                        vendor(filerId, "Filer Pharma", "27AAAAA0000A1Z5", "9811111111"),
                        vendor(laggardId, "Laggard Traders", "29BBBBB1111B1Z5", "9822222222"),
                        vendor(unregId, "Local Cash Shop", null, "9833333333")));

        ItcRiskReport r = service.assessRisk("2026-05");

        assertThat(r.dataAvailable()).isTrue();
        assertThat(r.suppliers()).hasSize(1);
        var risk = r.suppliers().get(0);
        assertThat(risk.contactId()).isEqualTo(laggardId);
        assertThat(risk.itcAtRisk()).isEqualByComparingTo("5500"); // 4000 + 1500
        assertThat(risk.invoiceCount()).isEqualTo(2);
        assertThat(risk.invoiceNumbers()).containsExactlyInAnyOrder("INV-9", "INV-10");
        assertThat(risk.whatsappUrl()).startsWith("https://wa.me/919822222222?text=");
        assertThat(r.totalItcAtRisk()).isEqualByComparingTo("5500");
    }

    @Test
    void raiseAlerts_createsOnePerSupplier_idempotent() {
        when(entryRepository.findByOrgIdAndReturnPeriodOrderBySupplierGstinAscInvoiceNumberAsc(orgId, "2026-05"))
                .thenReturn(List.of(filed("27AAAAA0000A1Z5", "INV-1")));
        when(purchaseBillRepository.findPostedByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(List.of(bill(laggardId, "INV-9", "12000")));
        when(contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), any()))
                .thenReturn(List.of(vendor(laggardId, "Laggard Traders", "29BBBBB1111B1Z5", "9822222222")));
        when(aiSuggestionRepository
                .findFirstByOrgIdAndEntityTypeAndEntityIdAndSuggestionTypeAndStatusInOrderByCreatedAtDesc(
                        eq(orgId), eq("CONTACT"), eq(laggardId), eq("ITC_AT_RISK"), any()))
                .thenReturn(java.util.Optional.empty());

        int raised = service.raiseAlerts("2026-05");

        assertThat(raised).isEqualTo(1);
        ArgumentCaptor<AiSuggestion> cap = ArgumentCaptor.forClass(AiSuggestion.class);
        verify(aiSuggestionService).createSuggestion(cap.capture());
        AiSuggestion s = cap.getValue();
        assertThat(s.getSuggestionType()).isEqualTo("ITC_AT_RISK");
        assertThat(s.getEntityId()).isEqualTo(laggardId);
        assertThat(s.getPriority()).isEqualTo("HIGH"); // ₹12000 + CRITICAL
        assertThat(s.getSuggestedValue()).containsKey("whatsappUrl");

        // Second run with the same urgency already on an open alert → no duplicate, no bump.
        when(aiSuggestionRepository
                .findFirstByOrgIdAndEntityTypeAndEntityIdAndSuggestionTypeAndStatusInOrderByCreatedAtDesc(
                        eq(orgId), eq("CONTACT"), eq(laggardId), eq("ITC_AT_RISK"), any()))
                .thenReturn(java.util.Optional.of(s)); // already at score 95
        assertThat(service.raiseAlerts("2026-05")).isZero();
        verify(aiSuggestionService, times(1)).createSuggestion(any());
    }

    @Test
    void raiseAlerts_escalatesExistingAlertAsDeadlineNears() {
        // An open alert raised earlier at low urgency (NORMAL, score 50).
        AiSuggestion stale = AiSuggestion.builder()
                .id(UUID.randomUUID()).orgId(orgId).entityType("CONTACT").entityId(laggardId)
                .suggestionType("ITC_AT_RISK").priority("MEDIUM")
                .priorityScore(new BigDecimal("50")).status("PENDING").build();
        when(entryRepository.findByOrgIdAndReturnPeriodOrderBySupplierGstinAscInvoiceNumberAsc(orgId, "2026-05"))
                .thenReturn(List.of(filed("27AAAAA0000A1Z5", "INV-1")));
        when(purchaseBillRepository.findPostedByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(List.of(bill(laggardId, "INV-9", "4000"))); // < ₹10k, so amount alone = MEDIUM
        when(contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), any()))
                .thenReturn(List.of(vendor(laggardId, "Laggard Traders", "29BBBBB1111B1Z5", "9822222222")));
        when(aiSuggestionRepository
                .findFirstByOrgIdAndEntityTypeAndEntityIdAndSuggestionTypeAndStatusInOrderByCreatedAtDesc(
                        eq(orgId), eq("CONTACT"), eq(laggardId), eq("ITC_AT_RISK"), any()))
                .thenReturn(java.util.Optional.of(stale));

        int created = service.raiseAlerts("2026-05"); // clock = CRITICAL (3 days out)

        assertThat(created).isZero(); // not a new alert — escalated in place
        verify(aiSuggestionService, never()).createSuggestion(any());
        ArgumentCaptor<AiSuggestion> cap = ArgumentCaptor.forClass(AiSuggestion.class);
        verify(aiSuggestionRepository).save(cap.capture());
        // ₹4000 (base 50) + CRITICAL (+25) = 75 → HIGH, bumped above the prior 50.
        assertThat(cap.getValue().getPriority()).isEqualTo("HIGH");
        assertThat(cap.getValue().getPriorityScore()).isEqualByComparingTo("75");
    }

    @Test
    void assess_surfacesProvenanceAndFreshness() {
        var now = java.time.Instant.parse("2026-06-05T09:00:00Z");
        when(filingSnapshotRepository.findByOrgIdAndReturnPeriod(orgId, "2026-05"))
                .thenReturn(java.util.Optional.of(
                        com.katasticho.erp.gst.entity.GstFilingSnapshot.builder()
                                .orgId(orgId).returnPeriod("2026-05")
                                .source("GSTR_2A").refreshedAt(now).entryCount(1).build()));
        when(entryRepository.findByOrgIdAndReturnPeriodOrderBySupplierGstinAscInvoiceNumberAsc(orgId, "2026-05"))
                .thenReturn(List.of(filed("27AAAAA0000A1Z5", "INV-1")));
        when(purchaseBillRepository.findPostedByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(List.of());

        ItcRiskReport r = service.assessRisk("2026-05");

        assertThat(r.source()).isEqualTo("GSTR_2A");
        assertThat(r.lastRefreshedAt()).isEqualTo(now);
    }

    @Test
    void rollup_splitsRecoverableFromPassedByDeadline() {
        // Same ₹4000 laggard in every period; clock = 2026-06-08.
        // months=3 from June → June (deadline Jul 11, open), May (Jun 11, 3d open),
        // Apr (May 11, passed). So recoverable = June+May = 8000, passed = Apr = 4000.
        when(entryRepository.findByOrgIdAndReturnPeriodOrderBySupplierGstinAscInvoiceNumberAsc(eq(orgId), anyString()))
                .thenReturn(List.of(filed("27AAAAA0000A1Z5", "INV-1")));
        when(purchaseBillRepository.findPostedByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(List.of(bill(laggardId, "INV-9", "4000")));
        when(contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), any()))
                .thenReturn(List.of(vendor(laggardId, "Laggard Traders", "29BBBBB1111B1Z5", "9822222222")));

        var rollup = service.recoverableRollup(3);

        assertThat(rollup.periods()).hasSize(3);
        assertThat(rollup.totalRecoverable()).isEqualByComparingTo("8000");
        assertThat(rollup.totalPassed()).isEqualByComparingTo("4000");
        assertThat(rollup.periods().get(0).period()).isEqualTo("2026-06"); // most recent first
        assertThat(rollup.periods().get(2).recoverable()).isFalse();       // April — passed
    }

    @Test
    void refreshAndAlert_pullsRealtime2aWhenGspConfigured() {
        when(gspClient.isConfigured(orgId)).thenReturn(true);
        when(gspClient.fetchGstr2a(orgId, "052026")).thenReturn(java.util.Map.of("entries", List.of()));
        when(entryRepository.findByOrgIdAndReturnPeriodOrderBySupplierGstinAscInvoiceNumberAsc(orgId, "2026-05"))
                .thenReturn(List.of(filed("27AAAAA0000A1Z5", "INV-1")));
        when(purchaseBillRepository.findPostedByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(List.of());

        service.refreshAndAlert("2026-05");

        // 2A pulled for the MMYYYY period and ingested, stamped as the GSTR_2A source.
        verify(gspClient).fetchGstr2a(orgId, "052026");
        verify(gstr2bReconService).upload(eq("2026-05"), anyMap(), eq("GSTR_2A"));
    }

    @Test
    void refreshAndAlert_gspFetchFailure_stillAlertsOnExistingData() {
        when(gspClient.isConfigured(orgId)).thenReturn(true);
        when(gspClient.fetchGstr2a(eq(orgId), anyString()))
                .thenThrow(new RuntimeException("GSP timeout"));
        when(entryRepository.findByOrgIdAndReturnPeriodOrderBySupplierGstinAscInvoiceNumberAsc(orgId, "2026-05"))
                .thenReturn(List.of(filed("27AAAAA0000A1Z5", "INV-1")));
        when(purchaseBillRepository.findPostedByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(List.of(bill(laggardId, "INV-9", "3000")));
        when(contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), any()))
                .thenReturn(List.of(vendor(laggardId, "Laggard Traders", "29BBBBB1111B1Z5", "9822222222")));
        when(aiSuggestionRepository.existsOpenSuggestion(any(), any(), any(), any(), any(), any()))
                .thenReturn(false);

        int raised = service.refreshAndAlert("2026-05");

        assertThat(raised).isEqualTo(1); // fetch failed but we still alerted on what we had
        verify(aiSuggestionService).createSuggestion(any());
    }
}
