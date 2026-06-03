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
import com.katasticho.erp.common.workflow.ApprovalWorkflowService;
import com.katasticho.erp.common.workflow.DocumentStateEngine;
import com.katasticho.erp.common.workflow.WorkflowDefinition;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.currency.CurrencyService;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
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
    @Mock private ContactRepository contactRepository;
    @Mock private InvoiceRepository invoiceRepository;
    @Mock private InvoiceNumberSequenceRepository sequenceRepository;
    @Mock private OrganisationRepository organisationRepository;
    @Mock private InvoiceService invoiceService;
    @Mock private JournalService journalService;
    @Mock private com.katasticho.erp.accounting.posting.AccountingPostingEngine postingEngine;
    @Mock private TaxEngine taxEngine;
    @Mock private AuditService auditService;
    @Mock private InventoryService inventoryService;
    @Mock private CommentService commentService;
    @Mock private CurrencyService currencyService;
    @Mock private DefaultAccountService defaultAccountService;
    @Mock private com.katasticho.erp.common.snapshot.DocumentSnapshotService documentSnapshotService;
    @Mock private ApprovalWorkflowService approvalWorkflowService;
    @Mock private DocumentStateEngine documentStateEngine;

    private CreditNoteService creditNoteService;
    private UUID orgId;
    private UUID userId;
    private Organisation org;
    private Contact contact;

    @BeforeEach
    void setUp() {
        creditNoteService = new CreditNoteService(
                creditNoteRepository, taxLineItemRepository, contactRepository,
                invoiceRepository, sequenceRepository, organisationRepository,
                invoiceService, journalService, postingEngine, taxEngine,
                currencyService, auditService, inventoryService,
                commentService, documentSnapshotService,
                approvalWorkflowService, documentStateEngine);

        lenient().when(currencyService.getRate(any(), any(), any())).thenReturn(BigDecimal.ONE);
        lenient().when(defaultAccountService.getCode(any(), eq(DefaultAccountPurpose.AR))).thenReturn("1200");

        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
        lenient().when(approvalWorkflowService.findMatchingWorkflow(eq(orgId), eq("CREDIT_NOTE"), anyMap()))
                .thenReturn(Optional.empty());

        org = Organisation.builder().name("Test Corp").stateCode("MH").build();
        org.setId(orgId);

        contact = Contact.builder().displayName("Acme Ltd").contactType(ContactType.CUSTOMER)
                .billingStateCode("MH").billingCountry("IN").build();
        contact.setId(UUID.randomUUID());
        contact.setOrgId(orgId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void shouldCreateAndIssueCreditNoteWithReversalJournal() {
        UUID invoiceId = UUID.randomUUID();
        Invoice invoice = Invoice.builder().orgId(orgId).contactId(contact.getId())
                .invoiceNumber("INV-2026-000001").status("SENT")
                .totalAmount(new BigDecimal("11800.00"))
                .amountPaid(BigDecimal.ZERO).balanceDue(new BigDecimal("11800.00"))
                .build();
        invoice.setId(invoiceId);

        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contact.getId(), orgId))
                .thenReturn(Optional.of(contact));
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

        UUID gstGroupId = UUID.randomUUID();
        when(taxEngine.resolveGroupId(eq(orgId), eq(new BigDecimal("18")), eq("MH"), eq("MH")))
                .thenReturn(Optional.of(gstGroupId));
        when(taxEngine.calculate(eq(orgId), eq(gstGroupId), eq(new BigDecimal("5000.00")), eq(TaxEngine.TransactionType.SALE)))
                .thenReturn(new TaxEngine.TaxCalculationResult(
                        List.of(
                                new TaxEngine.TaxComponent(UUID.randomUUID(), "CGST", "CGST 9%",
                                        new BigDecimal("9.00"), new BigDecimal("450.00"),
                                        UUID.randomUUID(), "2020", true),
                                new TaxEngine.TaxComponent(UUID.randomUUID(), "SGST", "SGST 9%",
                                        new BigDecimal("9.00"), new BigDecimal("450.00"),
                                        UUID.randomUUID(), "2021", true)),
                        new BigDecimal("900.00")));

        var request = new CreateCreditNoteRequest(
                contact.getId(),
                invoiceId,
                LocalDate.of(2026, 4, 15),
                "Defective goods returned",
                "MH",
                List.of(new CreditNoteLineRequest("Widget return", "8471", new BigDecimal("1"),
                        new BigDecimal("5000"), new BigDecimal("18"), "4010", null, null, null))
        );

        CreditNote cn = creditNoteService.createCreditNote(request);

        assertNotNull(cn);
        assertEquals("DRAFT", cn.getStatus());
        assertEquals(0, new BigDecimal("5000.00").compareTo(cn.getSubtotal()));
        assertEquals(0, new BigDecimal("900.00").compareTo(cn.getTaxAmount()));
        assertEquals(0, new BigDecimal("5900.00").compareTo(cn.getTotalAmount()));

        TaxLineItem cgst = TaxLineItem.builder().componentCode("CGST").accountCode("2020")
                .taxAmount(new BigDecimal("450.00")).build();
        TaxLineItem sgst = TaxLineItem.builder().componentCode("SGST").accountCode("2021")
                .taxAmount(new BigDecimal("450.00")).build();
        when(creditNoteRepository.findByIdAndOrgIdAndIsDeletedFalse(cn.getId(), orgId))
                .thenReturn(Optional.of(cn));
        when(invoiceRepository.findById(invoiceId)).thenReturn(Optional.of(invoice));

        JournalEntry mockJournal = JournalEntry.builder().entryNumber("JE-2026-000003").build();
        mockJournal.setId(UUID.randomUUID());
        when(postingEngine.postCreditNote(any(CreditNote.class))).thenReturn(mockJournal);

        CreditNote issued = creditNoteService.issueCreditNote(cn.getId());

        verify(postingEngine).postCreditNote(cn);
        assertEquals("APPLIED", issued.getStatus());
        assertEquals(mockJournal.getId(), issued.getJournalEntryId());

        verify(invoiceService).updatePaymentStatus(invoice, cn.getTotalAmount());
    }

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

    @Test
    void issueCreditNote_withMatchingWorkflow_marksPendingApprovalWithoutPosting() {
        CreditNote draftCn = CreditNote.builder()
                .orgId(orgId)
                .contactId(contact.getId())
                .creditNoteNumber("CN-2026-000010")
                .creditNoteDate(LocalDate.of(2026, 4, 15))
                .status("DRAFT")
                .totalAmount(new BigDecimal("7500.00"))
                .build();
        draftCn.setId(UUID.randomUUID());

        WorkflowDefinition workflow = WorkflowDefinition.builder()
                .code("CREDIT_NOTE_RETURN_APPROVAL")
                .name("Credit Note Return Approval")
                .documentType("CREDIT_NOTE")
                .triggerCondition("{}")
                .active(true)
                .build();
        workflow.setId(UUID.randomUUID());
        workflow.setOrgId(orgId);

        when(creditNoteRepository.findByIdAndOrgIdAndIsDeletedFalse(draftCn.getId(), orgId))
                .thenReturn(Optional.of(draftCn));
        when(approvalWorkflowService.findMatchingWorkflow(eq(orgId), eq("CREDIT_NOTE"), anyMap()))
                .thenReturn(Optional.of(workflow));
        when(creditNoteRepository.save(any(CreditNote.class))).thenAnswer(inv -> inv.getArgument(0));

        CreditNote result = creditNoteService.issueCreditNote(draftCn.getId());

        assertEquals("PENDING_APPROVAL", result.getStatus());
        verify(postingEngine, never()).postCreditNote(any());
        verify(approvalWorkflowService).requestApproval(
                eq(orgId),
                eq(workflow),
                eq("CREDIT_NOTE"),
                eq(draftCn.getId()),
                contains("requires approval"),
                anyMap());
    }

    @Test
    void issueApprovedCreditNote_postsPendingApprovalCreditNote() {
        CreditNote pendingCn = CreditNote.builder()
                .orgId(orgId)
                .contactId(contact.getId())
                .creditNoteNumber("CN-2026-000011")
                .creditNoteDate(LocalDate.of(2026, 4, 15))
                .status("PENDING_APPROVAL")
                .totalAmount(new BigDecimal("7500.00"))
                .build();
        pendingCn.setId(UUID.randomUUID());

        JournalEntry mockJournal = JournalEntry.builder().entryNumber("JE-2026-000004").build();
        mockJournal.setId(UUID.randomUUID());

        when(creditNoteRepository.findByIdAndOrgIdAndIsDeletedFalse(pendingCn.getId(), orgId))
                .thenReturn(Optional.of(pendingCn));
        when(postingEngine.postCreditNote(pendingCn)).thenReturn(mockJournal);
        when(creditNoteRepository.save(any(CreditNote.class))).thenAnswer(inv -> inv.getArgument(0));

        CreditNote result = creditNoteService.issueApprovedCreditNote(pendingCn.getId());

        assertEquals("ISSUED", result.getStatus());
        assertEquals(mockJournal.getId(), result.getJournalEntryId());
        verify(postingEngine).postCreditNote(pendingCn);
    }

    @Test
    void issueApprovedCreditNote_withLinkedInvoiceAppliesCreditOnlyAfterApproval() {
        UUID invoiceId = UUID.randomUUID();
        Invoice invoice = Invoice.builder()
                .orgId(orgId)
                .contactId(contact.getId())
                .invoiceNumber("INV-2026-000012")
                .status("SENT")
                .totalAmount(new BigDecimal("10000.00"))
                .amountPaid(BigDecimal.ZERO)
                .balanceDue(new BigDecimal("10000.00"))
                .build();
        invoice.setId(invoiceId);

        CreditNote pendingCn = CreditNote.builder()
                .orgId(orgId)
                .contactId(contact.getId())
                .invoiceId(invoiceId)
                .creditNoteNumber("CN-2026-000012")
                .creditNoteDate(LocalDate.of(2026, 4, 15))
                .status("PENDING_APPROVAL")
                .totalAmount(new BigDecimal("2500.00"))
                .build();
        pendingCn.setId(UUID.randomUUID());

        JournalEntry mockJournal = JournalEntry.builder().entryNumber("JE-2026-000005").build();
        mockJournal.setId(UUID.randomUUID());

        when(creditNoteRepository.findByIdAndOrgIdAndIsDeletedFalse(pendingCn.getId(), orgId))
                .thenReturn(Optional.of(pendingCn));
        when(postingEngine.postCreditNote(pendingCn)).thenReturn(mockJournal);
        when(invoiceRepository.findById(invoiceId)).thenReturn(Optional.of(invoice));
        when(creditNoteRepository.save(any(CreditNote.class))).thenAnswer(inv -> inv.getArgument(0));

        CreditNote result = creditNoteService.issueApprovedCreditNote(pendingCn.getId());

        assertEquals("APPLIED", result.getStatus());
        assertEquals(mockJournal.getId(), result.getJournalEntryId());
        verify(documentStateEngine).validateTransition(
                eq(orgId), eq("CREDIT_NOTE"), eq("PENDING_APPROVAL"), eq("ISSUED"));
        verify(postingEngine).postCreditNote(pendingCn);
        verify(invoiceService).updatePaymentStatus(invoice, new BigDecimal("2500.00"));
    }
}
