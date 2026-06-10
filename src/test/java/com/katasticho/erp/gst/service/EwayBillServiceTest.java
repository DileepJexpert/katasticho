package com.katasticho.erp.gst.service;

import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.service.AiSuggestionService;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.InvoiceLine;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.gst.dto.EwayBillDtos.EwayBillResponse;
import com.katasticho.erp.gst.dto.EwayBillDtos.RecordEwbRequest;
import com.katasticho.erp.gst.dto.EwayBillDtos.VehicleCheckRequest;
import com.katasticho.erp.gst.entity.EwayBill;
import com.katasticho.erp.gst.repository.EwayBillRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.sales.repository.DeliveryChallanRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class EwayBillServiceTest {

    private final EwayBillRepository ewayBillRepository = mock(EwayBillRepository.class);
    private final InvoiceRepository invoiceRepository = mock(InvoiceRepository.class);
    private final DeliveryChallanRepository deliveryChallanRepository = mock(DeliveryChallanRepository.class);
    private final ContactRepository contactRepository = mock(ContactRepository.class);
    private final OrganisationRepository organisationRepository = mock(OrganisationRepository.class);
    private final OrgSettingsService orgSettingsService = mock(OrgSettingsService.class);
    private final AiSuggestionService aiSuggestionService = mock(AiSuggestionService.class);

    private final EwayBillService service = new EwayBillService(
            ewayBillRepository, invoiceRepository, deliveryChallanRepository,
            contactRepository, organisationRepository, orgSettingsService, aiSuggestionService);

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        when(orgSettingsService.get(eq(orgId), eq(EwayBillService.THRESHOLD_SETTING), any()))
                .thenReturn("50000");
        when(organisationRepository.findById(orgId)).thenReturn(Optional.empty());
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(any(), eq(orgId)))
                .thenReturn(Optional.empty());
        when(ewayBillRepository.save(any(EwayBill.class))).thenAnswer(inv -> {
            EwayBill e = inv.getArgument(0);
            if (e.getId() == null) e.setId(UUID.randomUUID());
            return e;
        });
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void invoiceCrossingThresholdCreatesPendingEwbAndSuggestion() {
        UUID invoiceId = UUID.randomUUID();
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(Optional.of(invoice(invoiceId, "60000")));
        when(ewayBillRepository.existsByOrgIdAndDocumentTypeAndDocumentIdAndIsDeletedFalse(
                orgId, "INVOICE", invoiceId)).thenReturn(false);

        service.detectForInvoice(orgId, invoiceId);

        verify(ewayBillRepository).save(any(EwayBill.class));
        verify(aiSuggestionService).createSuggestion(any(AiSuggestion.class));
    }

    @Test
    void invoiceBelowThresholdIsIgnored() {
        UUID invoiceId = UUID.randomUUID();
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(Optional.of(invoice(invoiceId, "40000")));

        service.detectForInvoice(orgId, invoiceId);

        verify(ewayBillRepository, never()).save(any());
        verify(aiSuggestionService, never()).createSuggestion(any());
    }

    @Test
    void duplicateDetectionIsSkipped() {
        UUID invoiceId = UUID.randomUUID();
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(Optional.of(invoice(invoiceId, "60000")));
        when(ewayBillRepository.existsByOrgIdAndDocumentTypeAndDocumentIdAndIsDeletedFalse(
                orgId, "INVOICE", invoiceId)).thenReturn(true);

        service.detectForInvoice(orgId, invoiceId);

        verify(ewayBillRepository, never()).save(any());
    }

    @Test
    void vehicleAggregateRuleFlagsSubThresholdDocuments() {
        // Two documents of 30k + 25k in one vehicle — each below 50k, together above.
        EwayBill a = EwayBill.builder().documentType("INVOICE").documentId(UUID.randomUUID())
                .documentNumber("INV-A").documentDate(LocalDate.of(2026, 6, 10))
                .totalValue(new BigDecimal("30000")).build();
        EwayBill b = EwayBill.builder().documentType("INVOICE").documentId(UUID.randomUUID())
                .documentNumber("INV-B").documentDate(LocalDate.of(2026, 6, 10))
                .totalValue(new BigDecimal("25000")).build();
        when(ewayBillRepository.findByOrgIdAndVehicleNumberIgnoreCaseAndDocumentDateAndIsDeletedFalse(
                orgId, "MH12AB1234", LocalDate.of(2026, 6, 10)))
                .thenReturn(List.of(a, b));

        Map<String, Object> result = service.checkVehicle(new VehicleCheckRequest(
                "MH12AB1234", LocalDate.of(2026, 6, 10), null));

        assertThat((BigDecimal) result.get("aggregateValue")).isEqualByComparingTo("55000");
        assertThat(result.get("ewayBillRequired")).isEqualTo(true);
    }

    @Test
    void vehicleBelowThresholdNotRequired() {
        when(ewayBillRepository.findByOrgIdAndVehicleNumberIgnoreCaseAndDocumentDateAndIsDeletedFalse(
                any(), any(), any())).thenReturn(List.of());

        Map<String, Object> result = service.checkVehicle(new VehicleCheckRequest(
                "MH12AB1234", LocalDate.of(2026, 6, 10), new BigDecimal("20000")));

        assertThat(result.get("ewayBillRequired")).isEqualTo(false);
    }

    @Test
    void recordGeneratedComputesValidityFromDistance() {
        UUID id = UUID.randomUUID();
        EwayBill pending = EwayBill.builder()
                .documentType("INVOICE").documentId(UUID.randomUUID())
                .documentNumber("INV-1").documentDate(LocalDate.of(2026, 6, 10))
                .totalValue(new BigDecimal("60000")).distanceKm(350).build();
        pending.setId(id);
        pending.setOrgId(orgId);
        when(ewayBillRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(pending));

        EwayBillResponse resp = service.recordGenerated(id,
                new RecordEwbRequest("351012345678", "MH12AB1234", null));

        assertThat(resp.status()).isEqualTo("GENERATED");
        assertThat(resp.ewbNumber()).isEqualTo("351012345678");
        // 350 km at 200 km/day → 2 days of validity.
        assertThat(Duration.between(resp.generatedAt(), resp.validUntil()))
                .isEqualTo(Duration.ofDays(2));
    }

    @Test
    void computeValidityUsesOneDayPer200Km() {
        Instant now = Instant.now();
        assertThat(service.computeValidity(now, null)).isEqualTo(now.plus(Duration.ofDays(1)));
        assertThat(service.computeValidity(now, 200)).isEqualTo(now.plus(Duration.ofDays(1)));
        assertThat(service.computeValidity(now, 201)).isEqualTo(now.plus(Duration.ofDays(2)));
    }

    @Test
    void portalJsonBuildsNicShapeForIntraStateInvoice() {
        UUID invoiceId = UUID.randomUUID();
        Invoice invoice = invoice(invoiceId, "56000");
        invoice.getLines().add(InvoiceLine.builder()
                .invoice(invoice).lineNumber(1).description("Crocin 500mg")
                .hsnCode("3004").quantity(new BigDecimal("100"))
                .taxableAmount(new BigDecimal("50000")).gstRate(new BigDecimal("12"))
                .taxAmount(new BigDecimal("6000")).lineTotal(new BigDecimal("56000"))
                .build());
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(Optional.of(invoice));

        UUID ewbId = UUID.randomUUID();
        EwayBill ewb = EwayBill.builder()
                .documentType("INVOICE").documentId(invoiceId)
                .documentNumber("INV-77").documentDate(LocalDate.of(2026, 6, 1))
                .totalValue(new BigDecimal("56000"))
                .fromStateCode("27").toStateCode("27")
                .vehicleNumber("MH12AB1234").distanceKm(120)
                .build();
        ewb.setId(ewbId);
        ewb.setOrgId(orgId);
        when(ewayBillRepository.findByIdAndOrgIdAndIsDeletedFalse(ewbId, orgId))
                .thenReturn(Optional.of(ewb));

        Map<String, Object> json = service.portalJson(ewbId);

        @SuppressWarnings("unchecked")
        Map<String, Object> bill = ((List<Map<String, Object>>) json.get("billLists")).get(0);
        assertThat(bill.get("docNo")).isEqualTo("INV-77");
        assertThat(bill.get("transMode")).isEqualTo("1");
        // Intra-state: tax splits into CGST + SGST, no IGST.
        assertThat((BigDecimal) bill.get("cgstValue")).isEqualByComparingTo("3000");
        assertThat((BigDecimal) bill.get("sgstValue")).isEqualByComparingTo("3000");
        assertThat((BigDecimal) bill.get("igstValue")).isEqualByComparingTo("0");
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> items = (List<Map<String, Object>>) bill.get("itemList");
        assertThat(items).hasSize(1);
        assertThat(items.get(0).get("hsnCode")).isEqualTo("3004");
        assertThat((BigDecimal) items.get(0).get("cgstRate")).isEqualByComparingTo("6");
    }

    private Invoice invoice(UUID id, String total) {
        return Invoice.builder()
                .id(id)
                .orgId(orgId)
                .invoiceNumber("INV-77")
                .invoiceDate(LocalDate.of(2026, 6, 1))
                .contactId(UUID.randomUUID())
                .status("SENT")
                .totalAmount(new BigDecimal(total))
                .build();
    }
}
