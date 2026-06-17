package com.katasticho.erp.courier.service;

import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.service.AiSuggestionService;
import com.katasticho.erp.ar.dto.RecordPaymentRequest;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.Payment;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.service.PaymentService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.courier.dto.CodRemittanceDtos.*;
import com.katasticho.erp.courier.entity.CodRemittance;
import com.katasticho.erp.courier.entity.CourierShipment;
import com.katasticho.erp.courier.repository.CodRemittanceRepository;
import com.katasticho.erp.courier.repository.CourierShipmentRepository;
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
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class CodReconciliationServiceTest {

    @Mock private CodRemittanceRepository remittanceRepository;
    @Mock private CourierShipmentRepository shipmentRepository;
    @Mock private InvoiceRepository invoiceRepository;
    @Mock private PaymentService paymentService;
    @Mock private AiSuggestionService aiSuggestionService;
    private CodReconciliationService service;

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new CodReconciliationService(remittanceRepository, shipmentRepository,
                invoiceRepository, paymentService, aiSuggestionService);
        TenantContext.setCurrentOrgId(orgId);
        when(remittanceRepository.save(any(CodRemittance.class))).thenAnswer(inv -> {
            CodRemittance r = inv.getArgument(0);
            if (r.getId() == null) r.setId(UUID.randomUUID());
            for (var line : r.getLines()) {
                if (line.getId() == null) line.setId(UUID.randomUUID());
            }
            return r;
        });
    }

    @AfterEach
    void tearDown() { TenantContext.clear(); }

    private CreateCodRemittanceRequest req(BigDecimal net, CodLineInput... lines) {
        return new CreateCodRemittanceRequest("DELHIVERY", LocalDate.of(2026, 6, 17),
                "HDFC-1234", "UTRX", net, null, List.of(lines));
    }

    @Test
    void create_computesTotalsAndVariance() {
        // gross 1500, fees 30, expected net 1470, actual net 1465 → variance -5
        CodRemittanceResponse r = service.create(req(new BigDecimal("1465"),
                new CodLineInput("AWB1", new BigDecimal("1000"), new BigDecimal("20")),
                new CodLineInput("AWB2", new BigDecimal("500"), new BigDecimal("10"))));

        assertThat(r.grossCollected()).isEqualByComparingTo("1500");
        assertThat(r.totalFees()).isEqualByComparingTo("30");
        assertThat(r.expectedNet()).isEqualByComparingTo("1470");
        assertThat(r.variance()).isEqualByComparingTo("-5");   // courier short-remitted
        assertThat(r.status()).isEqualTo("DRAFT");
        assertThat(r.lines()).hasSize(2);
    }

    @Test
    void create_prematchesAwbToExistingShipment() {
        UUID shipmentId = UUID.randomUUID();
        UUID invoiceId = UUID.randomUUID();
        CourierShipment ship = CourierShipment.builder()
                .courierPartner("DELHIVERY").awbNumber("AWB1").invoiceId(invoiceId).build();
        ship.setId(shipmentId);
        when(shipmentRepository.findFirstByOrgIdAndCourierPartnerAndAwbNumberAndIsDeletedFalse(
                orgId, "DELHIVERY", "AWB1")).thenReturn(Optional.of(ship));

        CodRemittanceResponse r = service.create(req(new BigDecimal("980"),
                new CodLineInput("AWB1", new BigDecimal("1000"), new BigDecimal("20"))));

        assertThat(r.lines().get(0).courierShipmentId()).isEqualTo(shipmentId);
        assertThat(r.lines().get(0).invoiceId()).isEqualTo(invoiceId);
    }

    @Test
    void reconcile_matched_postsPaymentAndStampsShipment() {
        UUID shipmentId = UUID.randomUUID();
        UUID invoiceId = UUID.randomUUID();
        UUID paymentId = UUID.randomUUID();
        CourierShipment ship = CourierShipment.builder()
                .courierPartner("DELHIVERY").awbNumber("AWB1").invoiceId(invoiceId).build();
        ship.setId(shipmentId);
        ship.setOrgId(orgId);
        Invoice invoice = new Invoice();
        invoice.setId(invoiceId);
        invoice.setContactId(UUID.randomUUID());
        invoice.setBalanceDue(new BigDecimal("1000"));

        when(shipmentRepository.findFirstByOrgIdAndCourierPartnerAndAwbNumberAndIsDeletedFalse(
                orgId, "DELHIVERY", "AWB1")).thenReturn(Optional.of(ship));
        when(shipmentRepository.findByIdAndOrgIdAndIsDeletedFalse(shipmentId, orgId))
                .thenReturn(Optional.of(ship));
        when(invoiceRepository.findById(invoiceId)).thenReturn(Optional.of(invoice));
        Payment payment = new Payment();
        payment.setId(paymentId);
        when(paymentService.recordPayment(any(RecordPaymentRequest.class))).thenReturn(payment);

        CodRemittanceResponse created = service.create(req(new BigDecimal("980"),
                new CodLineInput("AWB1", new BigDecimal("1000"), new BigDecimal("20"))));
        when(remittanceRepository.findByIdAndOrgIdAndIsDeletedFalse(eq(created.id()), eq(orgId)))
                .thenAnswer(inv -> {
                    // The captured save returned the same instance we hold in created — refetch from the captor
                    ArgumentCaptor<CodRemittance> cap = ArgumentCaptor.forClass(CodRemittance.class);
                    verify(remittanceRepository, atLeastOnce()).save(cap.capture());
                    return Optional.of(cap.getValue());
                });

        ReconcileResult result = service.reconcile(created.id());

        assertThat(result.matched()).isEqualTo(1);
        assertThat(result.amountMismatch()).isZero();
        assertThat(result.orphan()).isZero();
        assertThat(result.totalSettled()).isEqualByComparingTo("1000");

        ArgumentCaptor<RecordPaymentRequest> pcap = ArgumentCaptor.forClass(RecordPaymentRequest.class);
        verify(paymentService).recordPayment(pcap.capture());
        RecordPaymentRequest pr = pcap.getValue();
        assertThat(pr.invoiceId()).isEqualTo(invoiceId);
        assertThat(pr.amount()).isEqualByComparingTo("1000");
        assertThat(pr.paymentMethod()).isEqualTo("COD_COLLECTION");
        assertThat(pr.referenceNumber()).isEqualTo("UTRX");
        assertThat(ship.getCodRemittanceLineId()).isNotNull();   // shipment stamped settled
    }

    @Test
    void reconcile_amountMismatch_flagsLineWithoutPosting() {
        UUID shipmentId = UUID.randomUUID();
        UUID invoiceId = UUID.randomUUID();
        CourierShipment ship = CourierShipment.builder()
                .courierPartner("DELHIVERY").awbNumber("AWB1").invoiceId(invoiceId).build();
        ship.setId(shipmentId);
        ship.setOrgId(orgId);
        Invoice invoice = new Invoice();
        invoice.setId(invoiceId);
        invoice.setBalanceDue(new BigDecimal("900"));   // doesn't match COD 1000

        when(shipmentRepository.findFirstByOrgIdAndCourierPartnerAndAwbNumberAndIsDeletedFalse(
                orgId, "DELHIVERY", "AWB1")).thenReturn(Optional.of(ship));
        when(shipmentRepository.findByIdAndOrgIdAndIsDeletedFalse(shipmentId, orgId))
                .thenReturn(Optional.of(ship));
        when(invoiceRepository.findById(invoiceId)).thenReturn(Optional.of(invoice));

        CodRemittanceResponse created = service.create(req(new BigDecimal("980"),
                new CodLineInput("AWB1", new BigDecimal("1000"), new BigDecimal("20"))));
        when(remittanceRepository.findByIdAndOrgIdAndIsDeletedFalse(eq(created.id()), eq(orgId)))
                .thenAnswer(inv -> {
                    ArgumentCaptor<CodRemittance> cap = ArgumentCaptor.forClass(CodRemittance.class);
                    verify(remittanceRepository, atLeastOnce()).save(cap.capture());
                    return Optional.of(cap.getValue());
                });

        ReconcileResult result = service.reconcile(created.id());

        assertThat(result.matched()).isZero();
        assertThat(result.amountMismatch()).isEqualTo(1);
        verify(paymentService, never()).recordPayment(any());
    }

    @Test
    void reconcile_orphan_raisesAiSuggestion() {
        when(shipmentRepository.findFirstByOrgIdAndCourierPartnerAndAwbNumberAndIsDeletedFalse(
                eq(orgId), eq("DELHIVERY"), any())).thenReturn(Optional.empty());
        when(shipmentRepository.findFirstByOrgIdAndAwbNumberAndIsDeletedFalse(eq(orgId), any()))
                .thenReturn(Optional.empty());

        CodRemittanceResponse created = service.create(req(new BigDecimal("980"),
                new CodLineInput("UNKNOWN-AWB", new BigDecimal("1000"), new BigDecimal("20"))));
        when(remittanceRepository.findByIdAndOrgIdAndIsDeletedFalse(eq(created.id()), eq(orgId)))
                .thenAnswer(inv -> {
                    ArgumentCaptor<CodRemittance> cap = ArgumentCaptor.forClass(CodRemittance.class);
                    verify(remittanceRepository, atLeastOnce()).save(cap.capture());
                    return Optional.of(cap.getValue());
                });

        ReconcileResult result = service.reconcile(created.id());

        assertThat(result.orphan()).isEqualTo(1);
        verify(paymentService, never()).recordPayment(any());
        ArgumentCaptor<AiSuggestion> scap = ArgumentCaptor.forClass(AiSuggestion.class);
        verify(aiSuggestionService).createSuggestion(scap.capture());
        AiSuggestion s = scap.getValue();
        assertThat(s.getSuggestionType()).isEqualTo("COD_ORPHAN_AWB");
        assertThat(s.getEntityType()).isEqualTo("COD_REMITTANCE_LINE");
        assertThat(s.getPriority()).isEqualTo("HIGH");
    }
}
