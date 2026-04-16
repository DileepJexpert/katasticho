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
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.currency.SimpleCurrencyService;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.organisation.BranchRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.pricing.service.PriceListService;
import com.katasticho.erp.tax.TaxEngine;
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
    @Mock private ContactRepository contactRepository;
    @Mock private InvoiceNumberSequenceRepository sequenceRepository;
    @Mock private OrganisationRepository organisationRepository;
    @Mock private BranchRepository branchRepository;
    @Mock private JournalService journalService;
    @Mock private TaxEngine taxEngine;
    @Mock private AuditService auditService;
    @Mock private InventoryService inventoryService;
    @Mock private PriceListService priceListService;
    @Mock private CommentService commentService;

    private InvoiceService invoiceService;
    private UUID orgId;
    private UUID userId;
    private Organisation org;
    private Customer customer;

    @BeforeEach
    void setUp() {
        invoiceService = new InvoiceService(
                invoiceRepository, taxLineItemRepository, customerRepository,
                contactRepository, sequenceRepository, organisationRepository,
                branchRepository,
                journalService, taxEngine, new SimpleCurrencyService(),
                auditService, inventoryService, priceListService, commentService);

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

    private void stubCustomerLookup(Customer c) {
        lenient().when(customerRepository.findById(c.getId())).thenReturn(Optional.of(c));
    }

    private void stubTaxLineLookup(UUID invoiceId, List<TaxLineItem> taxLines) {
        lenient().when(taxLineItemRepository.findBySourceTypeAndSourceId("INVOICE", invoiceId))
                .thenReturn(taxLines);
    }

    /** Stub taxEngine for intra-state GST 18%: CGST 9% + SGST 9% */
    private void stubIntraStateTax(BigDecimal taxableAmount) {
        UUID gstGroupId = UUID.randomUUID();
        lenient().when(taxEngine.resolveGroupId(eq(orgId), eq(new BigDecimal("18")), eq("MH"), eq("MH")))
                .thenReturn(Optional.of(gstGroupId));

        BigDecimal halfTax = taxableAmount.multiply(new BigDecimal("9"))
                .divide(BigDecimal.valueOf(100), 2, java.math.RoundingMode.HALF_UP);
        BigDecimal totalTax = halfTax.multiply(BigDecimal.valueOf(2));

        lenient().when(taxEngine.calculate(eq(orgId), eq(gstGroupId), eq(taxableAmount), eq(TaxEngine.TransactionType.SALE)))
                .thenReturn(new TaxEngine.TaxCalculationResult(
                        List.of(
                                new TaxEngine.TaxComponent(UUID.randomUUID(), "CGST", "CGST 9%",
                                        new BigDecimal("9.00"), halfTax, UUID.randomUUID(), "2020", true),
                                new TaxEngine.TaxComponent(UUID.randomUUID(), "SGST", "SGST 9%",
                                        new BigDecimal("9.00"), halfTax, UUID.randomUUID(), "2021", true)),
                        totalTax));
    }

    /** Stub taxEngine for inter-state GST 18%: IGST 18% */
    private void stubInterStateTax(BigDecimal taxableAmount) {
        UUID igstGroupId = UUID.randomUUID();
        lenient().when(taxEngine.resolveGroupId(eq(orgId), eq(new BigDecimal("18")), eq("MH"), eq("KA")))
                .thenReturn(Optional.of(igstGroupId));

        BigDecimal tax = taxableAmount.multiply(new BigDecimal("18"))
                .divide(BigDecimal.valueOf(100), 2, java.math.RoundingMode.HALF_UP);

        lenient().when(taxEngine.calculate(eq(orgId), eq(igstGroupId), eq(taxableAmount), eq(TaxEngine.TransactionType.SALE)))
                .thenReturn(new TaxEngine.TaxCalculationResult(
                        List.of(new TaxEngine.TaxComponent(UUID.randomUUID(), "IGST", "IGST 18%",
                                new BigDecimal("18.00"), tax, UUID.randomUUID(), "2022", true)),
                        tax));
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
            stubTaxLineLookup(i.getId(), Collections.emptyList());
            return i;
        });

        // 2 x 5000 = 10000 taxable
        stubIntraStateTax(new BigDecimal("10000.00"));

        var request = new CreateInvoiceRequest(
                customer.getId(),
                null,
                LocalDate.of(2026, 4, 11),
                null,
                "MH",
                false,
                "Test invoice",
                null,
                List.of(new InvoiceLineRequest("Widget", "8471", new BigDecimal("2"),
                        new BigDecimal("5000"), BigDecimal.ZERO, new BigDecimal("18"), "4010", null, null, null))
        );

        InvoiceResponse result = invoiceService.createInvoice(request);

        assertNotNull(result);
        assertEquals("DRAFT", result.status());
        assertEquals(0, new BigDecimal("10000.00").compareTo(result.subtotal()));
        assertEquals(0, new BigDecimal("1800.00").compareTo(result.taxAmount()));
        assertEquals(0, new BigDecimal("11800.00").compareTo(result.totalAmount()));
        assertEquals(0, new BigDecimal("11800.00").compareTo(result.balanceDue()));
        assertEquals(1, result.lines().size());
        assertEquals(LocalDate.of(2026, 5, 11), result.dueDate());

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

        // 1 x 10000 = 10000 taxable, inter-state
        stubInterStateTax(new BigDecimal("10000.00"));

        var request = new CreateInvoiceRequest(
                kaCustomer.getId(),
                null,
                LocalDate.of(2026, 4, 11),
                null,
                "KA",
                false, null, null,
                List.of(new InvoiceLineRequest("Service", "9983", BigDecimal.ONE,
                        new BigDecimal("10000"), BigDecimal.ZERO, new BigDecimal("18"), "4010", null, null, null))
        );

        InvoiceResponse result = invoiceService.createInvoice(request);

        assertEquals(0, new BigDecimal("10000.00").compareTo(result.subtotal()));
        assertEquals(0, new BigDecimal("1800.00").compareTo(result.taxAmount()));

        ArgumentCaptor<List<TaxLineItem>> taxCaptor = ArgumentCaptor.forClass(List.class);
        verify(taxLineItemRepository).saveAll(taxCaptor.capture());
        List<TaxLineItem> taxLines = taxCaptor.getValue();
        assertEquals(1, taxLines.size());
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

        var line = com.katasticho.erp.ar.entity.InvoiceLine.builder()
                .lineNumber(1).description("Widget").accountCode("4010")
                .taxableAmount(new BigDecimal("10000.00")).taxAmount(new BigDecimal("1800.00"))
                .lineTotal(new BigDecimal("11800.00")).build();
        draftInvoice.addLine(line);

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

        ArgumentCaptor<JournalPostRequest> journalCaptor = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(journalCaptor.capture());

        JournalPostRequest journalReq = journalCaptor.getValue();
        assertEquals("AR", journalReq.sourceModule());
        assertTrue(journalReq.autoPost());
        assertEquals(4, journalReq.lines().size());

        assertEquals(0, new BigDecimal("11800.00").compareTo(journalReq.lines().get(0).debit()));
        assertEquals("1200", journalReq.lines().get(0).accountCode());
        assertEquals(0, new BigDecimal("10000.00").compareTo(journalReq.lines().get(1).credit()));
        assertEquals("4010", journalReq.lines().get(1).accountCode());
        assertEquals(0, new BigDecimal("900.00").compareTo(journalReq.lines().get(2).credit()));
        assertEquals("2020", journalReq.lines().get(2).accountCode());
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

        // 10 x 1000 = 10000 gross, 10% discount = 9000 taxable
        stubIntraStateTax(new BigDecimal("9000.00"));

        var request = new CreateInvoiceRequest(
                customer.getId(),
                null,
                LocalDate.of(2026, 4, 11),
                null, "MH", false, null, null,
                List.of(new InvoiceLineRequest("Product", "8471", new BigDecimal("10"),
                        new BigDecimal("1000"), new BigDecimal("10"), new BigDecimal("18"), "4010", null, null, null))
        );

        InvoiceResponse result = invoiceService.createInvoice(request);

        assertEquals(0, new BigDecimal("9000.00").compareTo(result.subtotal()));
        assertEquals(0, new BigDecimal("1620.00").compareTo(result.taxAmount()));
        assertEquals(0, new BigDecimal("10620.00").compareTo(result.totalAmount()));
    }
}
