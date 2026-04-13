package com.katasticho.erp.ar.service;

import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ar.dto.CreateInvoiceRequest;
import com.katasticho.erp.ar.dto.InvoiceLineRequest;
import com.katasticho.erp.ar.dto.InvoiceResponse;
import com.katasticho.erp.ar.entity.Customer;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.TaxLineItem;
import com.katasticho.erp.ar.repository.*;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.currency.SimpleCurrencyService;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.pricing.service.PriceListService;
import com.katasticho.erp.tax.IndiaGSTEngine;
import com.katasticho.erp.tax.TaxEngineFactory;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Collections;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class InvoiceServiceTest {

    @Mock private InvoiceRepository invoiceRepository;
    @Mock private TaxLineItemRepository taxLineItemRepository;
    @Mock private CustomerRepository customerRepository;
    @Mock private InvoiceNumberSequenceRepository sequenceRepository;
    @Mock private OrganisationRepository organisationRepository;
    @Mock private JournalService journalService;
    @Mock private AuditService auditService;
    @Mock private InventoryService inventoryService;
    @Mock private PriceListService priceListService;

    private InvoiceService invoiceService;
    private TaxEngineFactory taxEngineFactory;
    private UUID orgId;
    private UUID userId;
    private Organisation org;
    private Customer customer;

    @BeforeEach
    void setUp() {
        taxEngineFactory = new TaxEngineFactory(List.of(new IndiaGSTEngine()));

        invoiceService = new InvoiceService(
                invoiceRepository, taxLineItemRepository, customerRepository,
                sequenceRepository, organisationRepository, journalService,
                taxEngineFactory, new SimpleCurrencyService(), auditService,
                inventoryService, priceListService);

        // By default the price list resolver returns empty — tests that
        // want to exercise a price override stub this per-test. Using
        // lenient() so the tests that don't create an invoice (send /
        // cancel paths) don't trip unused-stub failures.
        lenient().when(priceListService.resolvePrice(any(), any(), any()))
                .thenReturn(Optional.empty());

        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);

        org = Organisation.builder().name("Test Corp").stateCode("MH").build();
        org.setId(orgId);

        customer = Customer.builder().name("Acme Ltd").billingStateCode("MH").billingCountry("IN")
                .paymentTermsDays(30).build();
        customer.setId(UUID.randomUUID());
        customer.setOrgId(orgId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    /** Stub customerRepository.findById so toResponse() can resolve the customer name. */
    private void stubCustomerLookup(Customer c) {
        lenient().when(customerRepository.findById(c.getId())).thenReturn(Optional.of(c));
    }

    /** Stub taxLineItemRepository for toResponse() tax-line lookup. */
    private void stubTaxLineLookup(UUID invoiceId, List<TaxLineItem> taxLines) {
        lenient().when(taxLineItemRepository.findBySourceTypeAndSourceId("INVOICE", invoiceId))
                .thenReturn(taxLines);
    }

    // T-AR-01: Invoice creation with GST auto-calculation (intra-state CGST+SGST)
    @Test
    void shouldCreateInvoiceWithCgstSgst() {
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(customerRepository.findByIdAndOrgIdAndIsDeletedFalse(customer.getId(), orgId))
                .thenReturn(Optional.of(customer));
        stubCustomerLookup(customer);
        when(sequenceRepository.findByOrgIdAndPrefixAndYear(eq(orgId), eq("INV"), anyInt()))
                .thenReturn(Optional.empty());
        when(sequenceRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(invoiceRepository.save(any(Invoice.class))).thenAnswer(inv -> {
            Invoice i = inv.getArgument(0);
            if (i.getId() == null) i.setId(UUID.randomUUID());
            i.getLines().forEach(l -> {
                if (l.getId() == null) {
                    try {
                        var f = l.getClass().getDeclaredField("id");
                        f.setAccessible(true);
                        f.set(l, UUID.randomUUID());
                    } catch (Exception ignored) {}
                }
            });
            // Stub tax line lookup for toResponse() using the generated invoice ID
            stubTaxLineLookup(i.getId(), Collections.emptyList());
            return i;
        });

        var request = new CreateInvoiceRequest(
                customer.getId(),
                LocalDate.of(2026, 4, 11),
                null, // auto-calculate due date
                "MH", // same state as seller
                false,
                "Test invoice",
                null,
                List.of(new InvoiceLineRequest("Widget", "8471", new BigDecimal("2"),
                        new BigDecimal("5000"), BigDecimal.ZERO, new BigDecimal("18"), "4010", null, null))
        );

        InvoiceResponse result = invoiceService.createInvoice(request);

        assertNotNull(result);
        assertEquals("DRAFT", result.status());
        // 2 x 5000 = 10000 taxable, 18% GST = 1800
        assertEquals(0, new BigDecimal("10000.00").compareTo(result.subtotal()));
        assertEquals(0, new BigDecimal("1800.00").compareTo(result.taxAmount()));
        assertEquals(0, new BigDecimal("11800.00").compareTo(result.totalAmount()));
        assertEquals(0, new BigDecimal("11800.00").compareTo(result.balanceDue()));
        assertEquals(1, result.lines().size());

        // Due date should be invoice_date + 30 days
        assertEquals(LocalDate.of(2026, 5, 11), result.dueDate());

        // Verify tax line items were saved (CGST + SGST = 2 components)
        ArgumentCaptor<List<TaxLineItem>> taxCaptor = ArgumentCaptor.forClass(List.class);
        verify(taxLineItemRepository).saveAll(taxCaptor.capture());
        List<TaxLineItem> taxLines = taxCaptor.getValue();
        assertEquals(2, taxLines.size());
        assertEquals("CGST", taxLines.get(0).getComponentCode());
        assertEquals("SGST", taxLines.get(1).getComponentCode());
        assertEquals(0, new BigDecimal("900.00").compareTo(taxLines.get(0).getTaxAmount()));
        assertEquals(0, new BigDecimal("900.00").compareTo(taxLines.get(1).getTaxAmount()));
    }

    // T-AR-01b: Invoice creation with IGST (inter-state)
    @Test
    void shouldCreateInvoiceWithIgstForInterState() {
        Customer kaCustomer = Customer.builder().name("Bangalore Ltd")
                .billingStateCode("KA").billingCountry("IN").paymentTermsDays(30).build();
        kaCustomer.setId(UUID.randomUUID());
        kaCustomer.setOrgId(orgId);

        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(customerRepository.findByIdAndOrgIdAndIsDeletedFalse(kaCustomer.getId(), orgId))
                .thenReturn(Optional.of(kaCustomer));
        stubCustomerLookup(kaCustomer);
        when(sequenceRepository.findByOrgIdAndPrefixAndYear(eq(orgId), eq("INV"), anyInt()))
                .thenReturn(Optional.empty());
        when(sequenceRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(invoiceRepository.save(any(Invoice.class))).thenAnswer(inv -> {
            Invoice i = inv.getArgument(0);
            if (i.getId() == null) i.setId(UUID.randomUUID());
            i.getLines().forEach(l -> {
                try {
                    var f = l.getClass().getDeclaredField("id");
                    f.setAccessible(true);
                    f.set(l, UUID.randomUUID());
                } catch (Exception ignored) {}
            });
            stubTaxLineLookup(i.getId(), Collections.emptyList());
            return i;
        });

        var request = new CreateInvoiceRequest(
                kaCustomer.getId(),
                LocalDate.of(2026, 4, 11),
                null,
                "KA", // buyer state != seller state (MH)
                false, null, null,
                List.of(new InvoiceLineRequest("Service", "9983", BigDecimal.ONE,
                        new BigDecimal("10000"), BigDecimal.ZERO, new BigDecimal("18"), "4010", null, null))
        );

        InvoiceResponse result = invoiceService.createInvoice(request);

        assertEquals(0, new BigDecimal("10000.00").compareTo(result.subtotal()));
        assertEquals(0, new BigDecimal("1800.00").compareTo(result.taxAmount()));

        ArgumentCaptor<List<TaxLineItem>> taxCaptor = ArgumentCaptor.forClass(List.class);
        verify(taxLineItemRepository).saveAll(taxCaptor.capture());
        List<TaxLineItem> taxLines = taxCaptor.getValue();
        assertEquals(1, taxLines.size()); // Only IGST
        assertEquals("IGST", taxLines.get(0).getComponentCode());
        assertEquals(0, new BigDecimal("1800.00").compareTo(taxLines.get(0).getTaxAmount()));
    }

    // T-AR-02: sendInvoice() posts correct journal entry
    @Test
    void shouldPostJournalOnSendInvoice() {
        Invoice draftInvoice = Invoice.builder()
                .orgId(orgId).customerId(customer.getId())
                .invoiceNumber("INV-2026-000001").invoiceDate(LocalDate.of(2026, 4, 11))
                .dueDate(LocalDate.of(2026, 5, 11)).status("DRAFT")
                .subtotal(new BigDecimal("10000.00")).taxAmount(new BigDecimal("1800.00"))
                .totalAmount(new BigDecimal("11800.00")).balanceDue(new BigDecimal("11800.00"))
                .build();
        draftInvoice.setId(UUID.randomUUID());

        // Add a line
        var line = com.katasticho.erp.ar.entity.InvoiceLine.builder()
                .lineNumber(1).description("Widget").accountCode("4010")
                .taxableAmount(new BigDecimal("10000.00")).taxAmount(new BigDecimal("1800.00"))
                .lineTotal(new BigDecimal("11800.00")).build();
        draftInvoice.addLine(line);

        // Tax line items for the invoice
        TaxLineItem cgst = TaxLineItem.builder().componentCode("CGST").accountCode("2020")
                .taxAmount(new BigDecimal("900.00")).build();
        TaxLineItem sgst = TaxLineItem.builder().componentCode("SGST").accountCode("2021")
                .taxAmount(new BigDecimal("900.00")).build();

        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(draftInvoice.getId(), orgId))
                .thenReturn(Optional.of(draftInvoice));
        when(taxLineItemRepository.findBySourceTypeAndSourceId("INVOICE", draftInvoice.getId()))
                .thenReturn(List.of(cgst, sgst));
        stubCustomerLookup(customer);
        when(invoiceRepository.save(any(Invoice.class))).thenAnswer(inv -> inv.getArgument(0));

        JournalEntry mockJournal = JournalEntry.builder()
                .entryNumber("JE-2025-000001").status("POSTED").build();
        mockJournal.setId(UUID.randomUUID());
        when(journalService.postJournal(any(JournalPostRequest.class))).thenReturn(mockJournal);

        InvoiceResponse result = invoiceService.sendInvoice(draftInvoice.getId());

        assertEquals("SENT", result.status());
        assertNotNull(result.journalEntryId());

        // Verify journal was posted with correct lines
        ArgumentCaptor<JournalPostRequest> journalCaptor = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(journalCaptor.capture());

        JournalPostRequest journalReq = journalCaptor.getValue();
        assertEquals("AR", journalReq.sourceModule());
        assertTrue(journalReq.autoPost());

        // Should have: 1 DR (AR) + 1 CR (Revenue) + 2 CR (CGST, SGST) = 4 lines
        assertEquals(4, journalReq.lines().size());

        // DR AR = total amount
        assertEquals(0, new BigDecimal("11800.00").compareTo(journalReq.lines().get(0).debit()));
        assertEquals("1200", journalReq.lines().get(0).accountCode());

        // CR Revenue = subtotal
        assertEquals(0, new BigDecimal("10000.00").compareTo(journalReq.lines().get(1).credit()));
        assertEquals("4010", journalReq.lines().get(1).accountCode());

        // CR CGST
        assertEquals(0, new BigDecimal("900.00").compareTo(journalReq.lines().get(2).credit()));
        assertEquals("2020", journalReq.lines().get(2).accountCode());

        // CR SGST
        assertEquals(0, new BigDecimal("900.00").compareTo(journalReq.lines().get(3).credit()));
        assertEquals("2021", journalReq.lines().get(3).accountCode());
    }

    // T-AR-02b: Cannot send non-DRAFT invoice
    @Test
    void shouldRejectSendForNonDraftInvoice() {
        Invoice sentInvoice = Invoice.builder().orgId(orgId).status("SENT").build();
        sentInvoice.setId(UUID.randomUUID());

        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(sentInvoice.getId(), orgId))
                .thenReturn(Optional.of(sentInvoice));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> invoiceService.sendInvoice(sentInvoice.getId()));
        assertEquals("AR_INVOICE_NOT_DRAFT", ex.getErrorCode());
    }

    // T-AR-03: Cancel invoice with existing payments should fail
    @Test
    void shouldRejectCancelForInvoiceWithPayments() {
        Invoice paidInvoice = Invoice.builder().orgId(orgId).status("PARTIALLY_PAID")
                .amountPaid(new BigDecimal("5000.00")).build();
        paidInvoice.setId(UUID.randomUUID());

        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(paidInvoice.getId(), orgId))
                .thenReturn(Optional.of(paidInvoice));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> invoiceService.cancelInvoice(paidInvoice.getId(), "Test"));
        assertEquals("AR_INVOICE_HAS_PAYMENTS", ex.getErrorCode());
    }

    // T-AR-03b: Cancel SENT invoice should reverse journal
    @Test
    void shouldReverseJournalOnCancelSentInvoice() {
        UUID journalId = UUID.randomUUID();
        Invoice sentInvoice = Invoice.builder().orgId(orgId).customerId(customer.getId())
                .status("SENT").invoiceNumber("INV-2026-000001")
                .journalEntryId(journalId)
                .amountPaid(BigDecimal.ZERO)
                .build();
        sentInvoice.setId(UUID.randomUUID());

        JournalEntry reversal = JournalEntry.builder().entryNumber("JE-2026-000002").build();
        reversal.setId(UUID.randomUUID());

        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(sentInvoice.getId(), orgId))
                .thenReturn(Optional.of(sentInvoice));
        when(journalService.reverseEntry(journalId)).thenReturn(reversal);
        when(invoiceRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        stubCustomerLookup(customer);
        stubTaxLineLookup(sentInvoice.getId(), Collections.emptyList());

        InvoiceResponse result = invoiceService.cancelInvoice(sentInvoice.getId(), "Error in invoice");

        assertEquals("CANCELLED", result.status());
        verify(journalService).reverseEntry(journalId);
    }

    // Test discount calculation
    @Test
    void shouldApplyDiscountCorrectly() {
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(customerRepository.findByIdAndOrgIdAndIsDeletedFalse(customer.getId(), orgId))
                .thenReturn(Optional.of(customer));
        stubCustomerLookup(customer);
        when(sequenceRepository.findByOrgIdAndPrefixAndYear(eq(orgId), eq("INV"), anyInt()))
                .thenReturn(Optional.empty());
        when(sequenceRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(invoiceRepository.save(any(Invoice.class))).thenAnswer(inv -> {
            Invoice i = inv.getArgument(0);
            if (i.getId() == null) i.setId(UUID.randomUUID());
            i.getLines().forEach(l -> {
                try {
                    var f = l.getClass().getDeclaredField("id");
                    f.setAccessible(true);
                    f.set(l, UUID.randomUUID());
                } catch (Exception ignored) {}
            });
            stubTaxLineLookup(i.getId(), Collections.emptyList());
            return i;
        });

        // 10 items @ 1000 each, 10% discount, 18% GST
        var request = new CreateInvoiceRequest(
                customer.getId(),
                LocalDate.of(2026, 4, 11),
                null, "MH", false, null, null,
                List.of(new InvoiceLineRequest("Product", "8471", new BigDecimal("10"),
                        new BigDecimal("1000"), new BigDecimal("10"), new BigDecimal("18"), "4010", null, null))
        );

        InvoiceResponse result = invoiceService.createInvoice(request);

        // Gross = 10 x 1000 = 10000, discount = 10% of 10000 = 1000, taxable = 9000
        // Tax = 18% of 9000 = 1620, total = 9000 + 1620 = 10620
        assertEquals(0, new BigDecimal("9000.00").compareTo(result.subtotal()));
        assertEquals(0, new BigDecimal("1620.00").compareTo(result.taxAmount()));
        assertEquals(0, new BigDecimal("10620.00").compareTo(result.totalAmount()));
    }
}
