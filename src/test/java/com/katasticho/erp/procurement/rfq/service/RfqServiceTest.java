package com.katasticho.erp.procurement.rfq.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.procurement.dto.PurchaseOrderRequest;
import com.katasticho.erp.procurement.dto.PurchaseOrderResponse;
import com.katasticho.erp.procurement.entity.Supplier;
import com.katasticho.erp.procurement.repository.SupplierRepository;
import com.katasticho.erp.procurement.rfq.dto.CompareQuotesResponse;
import com.katasticho.erp.procurement.rfq.dto.CreateRfqRequest;
import com.katasticho.erp.procurement.rfq.dto.QuoteResponse;
import com.katasticho.erp.procurement.rfq.dto.RecordQuoteRequest;
import com.katasticho.erp.procurement.rfq.dto.RfqResponse;
import com.katasticho.erp.procurement.rfq.entity.Rfq;
import com.katasticho.erp.procurement.rfq.entity.RfqLine;
import com.katasticho.erp.procurement.rfq.entity.RfqSupplier;
import com.katasticho.erp.procurement.rfq.entity.SupplierQuote;
import com.katasticho.erp.procurement.rfq.entity.SupplierQuoteLine;
import com.katasticho.erp.procurement.rfq.repository.RfqLineRepository;
import com.katasticho.erp.procurement.rfq.repository.RfqRepository;
import com.katasticho.erp.procurement.rfq.repository.RfqSupplierRepository;
import com.katasticho.erp.procurement.rfq.repository.SupplierQuoteLineRepository;
import com.katasticho.erp.procurement.rfq.repository.SupplierQuoteRepository;
import com.katasticho.erp.procurement.service.PurchaseOrderService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class RfqServiceTest {

    private final RfqRepository rfqRepository = mock(RfqRepository.class);
    private final RfqLineRepository rfqLineRepository = mock(RfqLineRepository.class);
    private final RfqSupplierRepository rfqSupplierRepository = mock(RfqSupplierRepository.class);
    private final SupplierQuoteRepository supplierQuoteRepository = mock(SupplierQuoteRepository.class);
    private final SupplierQuoteLineRepository supplierQuoteLineRepository =
            mock(SupplierQuoteLineRepository.class);
    private final ContactRepository contactRepository = mock(ContactRepository.class);
    private final SupplierRepository supplierRepository = mock(SupplierRepository.class);
    private final PurchaseOrderService purchaseOrderService = mock(PurchaseOrderService.class);

    private final RfqService service = new RfqService(
            rfqRepository, rfqLineRepository, rfqSupplierRepository,
            supplierQuoteRepository, supplierQuoteLineRepository,
            contactRepository, supplierRepository, purchaseOrderService);

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private Contact vendor(UUID id, String name) {
        Contact c = new Contact();
        c.setId(id);
        c.setOrgId(orgId);
        c.setDisplayName(name);
        c.setContactType(ContactType.VENDOR);
        return c;
    }

    private Rfq stubRfq(UUID id, String status) {
        Rfq r = Rfq.builder().rfqNumber("RFQ-2026-00001").title("Cement").status(status).build();
        r.setId(id);
        r.setOrgId(orgId);
        return r;
    }

    // ── 1. Create ──
    @Test
    void createRfqDraftsHeaderAndLinesAndValidatesEachVendor() {
        UUID v1 = UUID.randomUUID();
        UUID v2 = UUID.randomUUID();
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(v1, orgId))
                .thenReturn(Optional.of(vendor(v1, "ACME")));
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(v2, orgId))
                .thenReturn(Optional.of(vendor(v2, "BETA")));
        when(rfqRepository.countByOrgIdAndIsDeletedFalse(orgId)).thenReturn(0L);
        when(rfqRepository.save(any(Rfq.class))).thenAnswer(inv -> {
            Rfq r = inv.getArgument(0);
            if (r.getId() == null) r.setId(UUID.randomUUID());
            return r;
        });

        CreateRfqRequest req = new CreateRfqRequest(
                "Cement Q3", LocalDate.of(2026, 7, 1), "rush",
                List.of(new CreateRfqRequest.LineRequest(
                        UUID.randomUUID(), "Cement 50kg",
                        new BigDecimal("100"), "2523", new BigDecimal("28"))),
                List.of(v1, v2));

        RfqResponse resp = service.createRfq(req);

        assertThat(resp.status()).isEqualTo("DRAFT");
        assertThat(resp.rfqNumber()).startsWith("RFQ-");
        assertThat(resp.lines()).hasSize(1);
        assertThat(resp.supplierContactIds()).containsExactly(v1, v2);

        ArgumentCaptor<List<RfqSupplier>> suppliers = ArgumentCaptor.forClass(List.class);
        verify(rfqSupplierRepository).saveAll(suppliers.capture());
        assertThat(suppliers.getValue()).hasSize(2);
    }

    @Test
    void createRfqRejectsNonVendorContact() {
        UUID customerId = UUID.randomUUID();
        Contact customer = new Contact();
        customer.setId(customerId);
        customer.setOrgId(orgId);
        customer.setDisplayName("RetailCo");
        customer.setContactType(ContactType.CUSTOMER);
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(customerId, orgId))
                .thenReturn(Optional.of(customer));

        CreateRfqRequest req = new CreateRfqRequest(
                "x", null, null,
                List.of(new CreateRfqRequest.LineRequest(
                        UUID.randomUUID(), "X", BigDecimal.ONE, null, null)),
                List.of(customerId));

        assertThatThrownBy(() -> service.createRfq(req))
                .isInstanceOf(BusinessException.class)
                .extracting(t -> ((BusinessException) t).getErrorCode())
                .isEqualTo("RFQ_NOT_VENDOR");
    }

    // ── 2. Send ──
    @Test
    void sendMovesDraftToSentAndRejectsRepeat() {
        UUID id = UUID.randomUUID();
        Rfq r = stubRfq(id, "DRAFT");
        when(rfqRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)).thenReturn(Optional.of(r));
        when(rfqRepository.save(any(Rfq.class))).thenAnswer(inv -> inv.getArgument(0));
        when(rfqLineRepository.findByRfqIdAndIsDeletedFalseOrderByCreatedAtAsc(id))
                .thenReturn(List.of());
        when(rfqSupplierRepository.findByRfqIdAndIsDeletedFalse(id)).thenReturn(List.of());

        RfqResponse resp = service.send(id);
        assertThat(resp.status()).isEqualTo("SENT");

        Rfq sent = stubRfq(id, "SENT");
        when(rfqRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)).thenReturn(Optional.of(sent));
        assertThatThrownBy(() -> service.send(id))
                .isInstanceOf(BusinessException.class)
                .extracting(t -> ((BusinessException) t).getErrorCode())
                .isEqualTo("RFQ_NOT_DRAFT");
    }

    // ── 3. Record quote ──
    @Test
    void recordQuoteCreatesQuoteWithLinesAndAutoNumber() {
        UUID rfqId = UUID.randomUUID();
        UUID supplierContact = UUID.randomUUID();
        when(rfqRepository.findByIdAndOrgIdAndIsDeletedFalse(rfqId, orgId))
                .thenReturn(Optional.of(stubRfq(rfqId, "SENT")));
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(supplierContact, orgId))
                .thenReturn(Optional.of(vendor(supplierContact, "ACME")));
        when(supplierQuoteRepository.countByOrgIdAndIsDeletedFalse(orgId)).thenReturn(0L);
        when(supplierQuoteRepository.save(any(SupplierQuote.class))).thenAnswer(inv -> {
            SupplierQuote q = inv.getArgument(0);
            if (q.getId() == null) q.setId(UUID.randomUUID());
            return q;
        });

        RecordQuoteRequest req = new RecordQuoteRequest(
                supplierContact, null, LocalDate.now().plusDays(14), null,
                List.of(new RecordQuoteRequest.QuoteLineRequest(
                        UUID.randomUUID(), "Cement",
                        new BigDecimal("100"), new BigDecimal("12.50"), 5, null)));

        QuoteResponse resp = service.recordQuote(rfqId, req);

        assertThat(resp.status()).isEqualTo("RECEIVED");
        assertThat(resp.quoteNumber()).startsWith("SQ-");
        assertThat(resp.totalAmount()).isEqualByComparingTo(new BigDecimal("1250.00"));
        assertThat(resp.lines()).hasSize(1);
    }

    // ── 4. Compare ──
    @Test
    void compareQuotesPicksLowestPerLineAndLowestTotal() {
        UUID rfqId = UUID.randomUUID();
        UUID supplier1 = UUID.randomUUID();
        UUID supplier2 = UUID.randomUUID();
        UUID supplier3 = UUID.randomUUID();
        UUID itemA = UUID.randomUUID();
        UUID itemB = UUID.randomUUID();
        when(rfqRepository.findByIdAndOrgIdAndIsDeletedFalse(rfqId, orgId))
                .thenReturn(Optional.of(stubRfq(rfqId, "SENT")));

        // Cheapest quote overall: supplier1 (1200), then supplier3 (1400), then supplier2 (1500)
        SupplierQuote q1 = quote(UUID.randomUUID(), rfqId, supplier1, "1200", "SQ-1");
        SupplierQuote q2 = quote(UUID.randomUUID(), rfqId, supplier2, "1500", "SQ-2");
        SupplierQuote q3 = quote(UUID.randomUUID(), rfqId, supplier3, "1400", "SQ-3");
        when(supplierQuoteRepository.findByRfqIdAndIsDeletedFalseOrderByTotalAmountAsc(rfqId))
                .thenReturn(List.of(q1, q3, q2));

        // Per-line: itemA cheapest from supplier1 (10 vs 12 vs 11); itemB cheapest from supplier3 (5).
        when(supplierQuoteLineRepository.findBySupplierQuoteIdInAndIsDeletedFalse(
                List.of(q1.getId(), q3.getId(), q2.getId())))
                .thenReturn(List.of(
                        line(q1.getId(), itemA, "10", 3),
                        line(q1.getId(), itemB, "8", 3),
                        line(q2.getId(), itemA, "12", 7),
                        line(q2.getId(), itemB, "6", 7),
                        line(q3.getId(), itemA, "11", 5),
                        line(q3.getId(), itemB, "5", 5)));

        CompareQuotesResponse cmp = service.compareQuotes(rfqId);

        assertThat(cmp.lowestTotalQuoteId()).isEqualTo(q1.getId());
        assertThat(cmp.supplierSummaries()).hasSize(3);
        assertThat(cmp.lineComparisons()).hasSize(2);
        var aCmp = cmp.lineComparisons().stream()
                .filter(l -> itemA.equals(l.itemId())).findFirst().orElseThrow();
        assertThat(aCmp.lowestPriceQuoteId()).isEqualTo(q1.getId());
        assertThat(aCmp.lowestUnitPrice()).isEqualByComparingTo("10");
        var bCmp = cmp.lineComparisons().stream()
                .filter(l -> itemB.equals(l.itemId())).findFirst().orElseThrow();
        assertThat(bCmp.lowestPriceQuoteId()).isEqualTo(q3.getId());
    }

    // ── 5. Award ──
    @Test
    void awardFlipsLifecycleAndDraftsPoWithWinningPrices() {
        UUID rfqId = UUID.randomUUID();
        UUID winnerQuoteId = UUID.randomUUID();
        UUID loserQuoteId = UUID.randomUUID();
        UUID supplierContact = UUID.randomUUID();
        UUID supplierId = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();
        Rfq rfq = stubRfq(rfqId, "SENT");
        when(rfqRepository.findByIdAndOrgIdAndIsDeletedFalse(rfqId, orgId)).thenReturn(Optional.of(rfq));

        SupplierQuote winner = quote(winnerQuoteId, rfqId, supplierContact, "1200", "SQ-W");
        SupplierQuote loser = quote(loserQuoteId, rfqId, UUID.randomUUID(), "1500", "SQ-L");
        when(supplierQuoteRepository.findByIdAndOrgIdAndIsDeletedFalse(winnerQuoteId, orgId))
                .thenReturn(Optional.of(winner));
        when(supplierQuoteRepository.findByRfqIdAndIsDeletedFalseOrderByTotalAmountAsc(rfqId))
                .thenReturn(List.of(winner, loser));

        Contact vendorContact = vendor(supplierContact, "ACME");
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(supplierContact, orgId))
                .thenReturn(Optional.of(vendorContact));

        Supplier supplier = Supplier.builder().name("ACME").build();
        supplier.setId(supplierId);
        supplier.setOrgId(orgId);
        when(supplierRepository.findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(orgId, "ACME"))
                .thenReturn(Optional.of(supplier));

        when(supplierQuoteLineRepository
                .findBySupplierQuoteIdAndIsDeletedFalseOrderByCreatedAtAsc(winnerQuoteId))
                .thenReturn(List.of(
                        SupplierQuoteLine.builder()
                                .supplierQuoteId(winnerQuoteId).itemId(itemId)
                                .description("Cement").quantity(new BigDecimal("100"))
                                .unitPrice(new BigDecimal("12.00")).leadTimeDays(5).build()));

        PurchaseOrderResponse poResp = new PurchaseOrderResponse(
                UUID.randomUUID(), orgId, supplierId, "ACME",
                "PO-00001", "DRAFT", LocalDate.now(), null, null, null,
                new BigDecimal("1200"), List.of(), java.time.Instant.now());
        when(purchaseOrderService.create(any(PurchaseOrderRequest.class))).thenReturn(poResp);

        when(rfqRepository.save(any(Rfq.class))).thenAnswer(inv -> inv.getArgument(0));
        when(supplierQuoteRepository.save(any(SupplierQuote.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        var result = service.award(rfqId, winnerQuoteId);

        assertThat(result.winningQuoteId()).isEqualTo(winnerQuoteId);
        assertThat(result.purchaseOrder().poNumber()).isEqualTo("PO-00001");

        ArgumentCaptor<PurchaseOrderRequest> poCaptor =
                ArgumentCaptor.forClass(PurchaseOrderRequest.class);
        verify(purchaseOrderService).create(poCaptor.capture());
        PurchaseOrderRequest createdReq = poCaptor.getValue();
        assertThat(createdReq.supplierId()).isEqualTo(supplierId);
        assertThat(createdReq.lines()).hasSize(1);
        assertThat(createdReq.lines().get(0).unitPrice()).isEqualByComparingTo("12.00");
        assertThat(createdReq.lines().get(0).itemId()).isEqualTo(itemId);

        assertThat(winner.getStatus()).isEqualTo("AWARDED");
        assertThat(loser.getStatus()).isEqualTo("REJECTED");
        assertThat(rfq.getStatus()).isEqualTo("AWARDED");
    }

    // ── 6. Cancel ──
    @Test
    void cancelFromDraftAndFromSentSucceedsButTerminalThrows() {
        UUID id = UUID.randomUUID();
        when(rfqRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(stubRfq(id, "DRAFT")));
        when(rfqRepository.save(any(Rfq.class))).thenAnswer(inv -> inv.getArgument(0));
        when(rfqLineRepository.findByRfqIdAndIsDeletedFalseOrderByCreatedAtAsc(id))
                .thenReturn(List.of());
        when(rfqSupplierRepository.findByRfqIdAndIsDeletedFalse(id)).thenReturn(List.of());

        RfqResponse cancelled = service.cancel(id, "test");
        assertThat(cancelled.status()).isEqualTo("CANCELLED");

        when(rfqRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(stubRfq(id, "AWARDED")));
        assertThatThrownBy(() -> service.cancel(id, "x"))
                .isInstanceOf(BusinessException.class)
                .extracting(t -> ((BusinessException) t).getErrorCode())
                .isEqualTo("RFQ_TERMINAL");

        when(rfqRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(stubRfq(id, "CANCELLED")));
        assertThatThrownBy(() -> service.cancel(id, "x"))
                .isInstanceOf(BusinessException.class)
                .extracting(t -> ((BusinessException) t).getErrorCode())
                .isEqualTo("RFQ_TERMINAL");

        // PO service never called
        verify(purchaseOrderService, never()).create(any());
    }

    // ── Helpers ──
    private SupplierQuote quote(UUID id, UUID rfqId, UUID contactId, String total, String num) {
        SupplierQuote q = SupplierQuote.builder()
                .rfqId(rfqId).supplierContactId(contactId).quoteNumber(num)
                .totalAmount(new BigDecimal(total)).currency("INR").status("RECEIVED").build();
        q.setId(id);
        q.setOrgId(orgId);
        return q;
    }

    private SupplierQuoteLine line(UUID quoteId, UUID itemId, String price, Integer lead) {
        SupplierQuoteLine l = SupplierQuoteLine.builder()
                .supplierQuoteId(quoteId).itemId(itemId).quantity(new BigDecimal("10"))
                .unitPrice(new BigDecimal(price)).leadTimeDays(lead).build();
        l.setId(UUID.randomUUID());
        l.setOrgId(orgId);
        return l;
    }
}
