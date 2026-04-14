package com.katasticho.erp.ar.service;

import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ar.dto.CreateCreditNoteRequest;
import com.katasticho.erp.ar.dto.CreditNoteLineRequest;
import com.katasticho.erp.ar.entity.*;
import com.katasticho.erp.ar.repository.*;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.currency.SimpleCurrencyService;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
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
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CreditNoteServiceTest {

    @Mock private CreditNoteRepository creditNoteRepository;
    @Mock private TaxLineItemRepository taxLineItemRepository;
    @Mock private CustomerRepository customerRepository;
    @Mock private InvoiceRepository invoiceRepository;
    @Mock private InvoiceNumberSequenceRepository sequenceRepository;
    @Mock private OrganisationRepository organisationRepository;
    @Mock private InvoiceService invoiceService;
    @Mock private JournalService journalService;
    @Mock private AuditService auditService;
    @Mock private InventoryService inventoryService;
    @Mock private CommentService commentService;

    private CreditNoteService creditNoteService;
    private UUID orgId;
    private UUID userId;
    private Organisation org;
    private Customer customer;

    @BeforeEach
    void setUp() {
        TaxEngineFactory taxEngineFactory = new TaxEngineFactory(List.of(new IndiaGSTEngine()));

        creditNoteService = new CreditNoteService(
                creditNoteRepository, taxLineItemRepository, customerRepository,
                invoiceRepository, sequenceRepository, organisationRepository,
                invoiceService, journalService, taxEngineFactory,
                new SimpleCurrencyService(), auditService, inventoryService,
                commentService);

        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);

        org = Organisation.builder().name("Test Corp").stateCode("MH").build();
        org.setId(orgId);

        customer = Customer.builder().name("Acme Ltd").billingStateCode("MH")
                .billingCountry("IN").build();
        customer.setId(UUID.randomUUID());
        customer.setOrgId(orgId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // T-AR-05: Credit note creates correct reversal journal
    @Test
    void shouldCreateAndIssueCreditNoteWithReversalJournal() {
        UUID invoiceId = UUID.randomUUID();
        Invoice invoice = Invoice.builder().orgId(orgId).customerId(customer.getId())
                .invoiceNumber("INV-2026-000001").status("SENT")
                .totalAmount(new BigDecimal("11800.00"))
                .amountPaid(BigDecimal.ZERO).balanceDue(new BigDecimal("11800.00"))
                .build();
        invoice.setId(invoiceId);

        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(customerRepository.findByIdAndOrgIdAndIsDeletedFalse(customer.getId(), orgId))
                .thenReturn(Optional.of(customer));
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(Optional.of(invoice));
        when(invoiceService.computeFiscalYear(any(LocalDate.class), anyInt())).thenReturn(2026);
        when(invoiceService.generateNumber(eq(orgId), eq("CN"), anyInt()))
                .thenReturn("CN-2026-000001");
        when(creditNoteRepository.save(any(CreditNote.class))).thenAnswer(inv -> {
            CreditNote cn = inv.getArgument(0);
            if (cn.getId() == null) cn.setId(UUID.randomUUID());
            return cn;
        });

        // Create credit note
        var request = new CreateCreditNoteRequest(
                customer.getId(),
                null, // contactId — legacy test, customerId path
                invoiceId,
                LocalDate.of(2026, 4, 15),
                "Defective goods returned",
                "MH",
                List.of(new CreditNoteLineRequest("Widget return", "8471", new BigDecimal("1"),
                        new BigDecimal("5000"), new BigDecimal("18"), "4010", null, null))
        );

        CreditNote cn = creditNoteService.createCreditNote(request);

        assertNotNull(cn);
        assertEquals("DRAFT", cn.getStatus());
        // 1 x 5000 = 5000 taxable, 18% GST = 900 (CGST 450 + SGST 450)
        assertEquals(0, new BigDecimal("5000.00").compareTo(cn.getSubtotal()));
        assertEquals(0, new BigDecimal("900.00").compareTo(cn.getTaxAmount()));
        assertEquals(0, new BigDecimal("5900.00").compareTo(cn.getTotalAmount()));

        // Now issue the credit note
        TaxLineItem cgst = TaxLineItem.builder().componentCode("CGST").accountCode("2020")
                .taxAmount(new BigDecimal("450.00")).build();
        TaxLineItem sgst = TaxLineItem.builder().componentCode("SGST").accountCode("2021")
                .taxAmount(new BigDecimal("450.00")).build();
        when(creditNoteRepository.findByIdAndOrgIdAndIsDeletedFalse(cn.getId(), orgId))
                .thenReturn(Optional.of(cn));
        when(taxLineItemRepository.findBySourceTypeAndSourceId("CREDIT_NOTE", cn.getId()))
                .thenReturn(List.of(cgst, sgst));
        when(invoiceRepository.findById(invoiceId)).thenReturn(Optional.of(invoice));

        JournalEntry mockJournal = JournalEntry.builder().entryNumber("JE-2026-000003").build();
        mockJournal.setId(UUID.randomUUID());
        when(journalService.postJournal(any(JournalPostRequest.class))).thenReturn(mockJournal);

        CreditNote issued = creditNoteService.issueCreditNote(cn.getId());

        // Verify the journal was posted
        ArgumentCaptor<JournalPostRequest> captor = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(captor.capture());

        JournalPostRequest journalReq = captor.getValue();
        assertEquals("AR", journalReq.sourceModule());

        // Journal should reverse the invoice entry:
        // DR Revenue (4010) = 5000 (reversal of revenue)
        // DR CGST Payable (2020) = 450 (reversal of tax)
        // DR SGST Payable (2021) = 450 (reversal of tax)
        // CR AR (1200) = 5900 (reduces receivable)
        assertEquals(4, journalReq.lines().size());

        // DR Revenue
        assertEquals("4010", journalReq.lines().get(0).accountCode());
        assertEquals(0, new BigDecimal("5000.00").compareTo(journalReq.lines().get(0).debit()));

        // DR CGST
        assertEquals("2020", journalReq.lines().get(1).accountCode());
        assertEquals(0, new BigDecimal("450.00").compareTo(journalReq.lines().get(1).debit()));

        // DR SGST
        assertEquals("2021", journalReq.lines().get(2).accountCode());
        assertEquals(0, new BigDecimal("450.00").compareTo(journalReq.lines().get(2).debit()));

        // CR AR
        assertEquals("1200", journalReq.lines().get(3).accountCode());
        assertEquals(0, new BigDecimal("5900.00").compareTo(journalReq.lines().get(3).credit()));

        // Invoice balance should be updated
        verify(invoiceService).updatePaymentStatus(invoice, cn.getTotalAmount());
    }

    // T-AR-05b: Cannot issue non-DRAFT credit note
    @Test
    void shouldRejectIssueForNonDraftCreditNote() {
        CreditNote issuedCn = CreditNote.builder().orgId(orgId).status("ISSUED").build();
        issuedCn.setId(UUID.randomUUID());

        when(creditNoteRepository.findByIdAndOrgIdAndIsDeletedFalse(issuedCn.getId(), orgId))
                .thenReturn(Optional.of(issuedCn));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> creditNoteService.issueCreditNote(issuedCn.getId()));
        assertEquals("AR_CN_NOT_DRAFT", ex.getErrorCode());
    }
}
