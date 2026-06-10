package com.katasticho.erp.ar.service;

import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.posting.AccountingPostingEngine;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ar.dto.PaymentResponse;
import com.katasticho.erp.ar.dto.RecordPaymentForInvoiceRequest;
import com.katasticho.erp.ar.dto.RecordPaymentRequest;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.Payment;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.repository.PaymentRepository;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.common.workflow.ApprovalWorkflowService;
import com.katasticho.erp.common.workflow.DocumentStateConfig;
import com.katasticho.erp.common.workflow.DocumentStateEngine;
import com.katasticho.erp.common.workflow.WorkflowDefinition;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.currency.CurrencyService;
import com.katasticho.erp.organisation.BranchRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PaymentServiceTest {

    @Mock private PaymentRepository paymentRepository;
    @Mock private InvoiceRepository invoiceRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private OrganisationRepository organisationRepository;
    @Mock private BranchRepository branchRepository;
    @Mock private JournalService journalService;
    @Mock private com.katasticho.erp.accounting.posting.AccountingPostingEngine postingEngine;
    @Mock private InvoiceService invoiceService;
    @Mock private AuditService auditService;
    @Mock private CommentService commentService;
    @Mock private CurrencyService currencyService;
    @Mock private com.katasticho.erp.common.snapshot.DocumentSnapshotService documentSnapshotService;
    @Mock private ApprovalWorkflowService approvalWorkflowService;
    @Mock private DocumentStateEngine documentStateEngine;

    private PaymentService paymentService;
    private UUID orgId;
    private UUID userId;
    private Organisation org;
    private Map<UUID, Payment> savedPayments;

    @BeforeEach
    void setUp() {
        paymentService = new PaymentService(
                paymentRepository, invoiceRepository, contactRepository,
                organisationRepository, branchRepository, journalService, postingEngine,
                invoiceService, currencyService, auditService, commentService, documentSnapshotService,
                approvalWorkflowService, documentStateEngine);

        lenient().when(currencyService.getRate(any(), any(), any())).thenReturn(BigDecimal.ONE);
        lenient().when(approvalWorkflowService.findMatchingWorkflow(any(), any(), anyMap()))
                .thenReturn(Optional.empty());
        lenient().when(documentStateEngine.validateTransition(any(), any(), any(), any()))
                .thenReturn(DocumentStateConfig.builder().build());
        savedPayments = new HashMap<>();
        lenient().when(paymentRepository.save(any(Payment.class))).thenAnswer(inv -> {
            Payment p = inv.getArgument(0);
            if (p.getId() == null) p.setId(UUID.randomUUID());
            savedPayments.put(p.getId(), p);
            return p;
        });
        lenient().when(paymentRepository.findByIdAndOrgIdAndIsDeletedFalse(any(UUID.class), any(UUID.class)))
                .thenAnswer(inv -> Optional.ofNullable(savedPayments.get(inv.getArgument(0))));

        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);

        org = Organisation.builder().name("Test Corp").build();
        org.setId(orgId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void shouldPostJournalOnPayment() {
        Invoice invoice = Invoice.builder()
                .orgId(orgId).contactId(UUID.randomUUID())
                .invoiceNumber("INV-2026-000001").status("SENT")
                .totalAmount(new BigDecimal("11800.00"))
                .amountPaid(BigDecimal.ZERO)
                .balanceDue(new BigDecimal("11800.00"))
                .build();
        invoice.setId(UUID.randomUUID());

        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoice.getId(), orgId))
                .thenReturn(Optional.of(invoice));
        when(invoiceService.computeFiscalYear(any(LocalDate.class), anyInt())).thenReturn(2026);
        when(invoiceService.generateNumber(eq(orgId), eq("PAY"), anyInt()))
                .thenReturn("PAY-2026-000001");

        JournalEntry mockJournal = JournalEntry.builder()
                .entryNumber("JE-2026-000002").status("POSTED").build();
        mockJournal.setId(UUID.randomUUID());
        when(postingEngine.postPaymentReceived(any(), any(), any(), any(), any(), any()))
                .thenReturn(mockJournal);
        var request = new RecordPaymentRequest(
                invoice.getId(),
                null,
                LocalDate.of(2026, 4, 15),
                new BigDecimal("5000"),
                "BANK_TRANSFER",
                "UTR123456",
                "HDFC-001",
                "Partial payment"
        );

        Payment result = paymentService.recordPayment(request);

        assertNotNull(result);
        assertEquals("PAY-2026-000001", result.getPaymentNumber());
        assertEquals(0, new BigDecimal("5000").compareTo(result.getAmount()));
        assertEquals(com.katasticho.erp.ar.entity.PaymentStatus.POSTED, result.getStatus());
        assertNotNull(result.getPostedAt());
        assertEquals(userId, result.getPostedBy());

        verify(postingEngine).postPaymentReceived(
                eq(orgId), eq("PAY-2026-000001"), eq("INV-2026-000001"),
                eq(LocalDate.of(2026, 4, 15)), eq(new BigDecimal("5000")), eq("BANK_TRANSFER"));

        verify(invoiceService).updatePaymentStatus(invoice, new BigDecimal("5000"));
    }

    @Test
    void shouldRejectPaymentExceedingBalance() {
        Invoice invoice = Invoice.builder()
                .orgId(orgId).status("SENT")
                .totalAmount(new BigDecimal("1000.00"))
                .amountPaid(BigDecimal.ZERO)
                .balanceDue(new BigDecimal("1000.00"))
                .build();
        invoice.setId(UUID.randomUUID());

        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoice.getId(), orgId))
                .thenReturn(Optional.of(invoice));

        var request = new RecordPaymentRequest(
                invoice.getId(),
                null,
                LocalDate.now(),
                new BigDecimal("1500"),
                "CASH", null, null, null
        );

        BusinessException ex = assertThrows(BusinessException.class,
                () -> paymentService.recordPayment(request));
        assertEquals("AR_PAYMENT_EXCEEDS_BALANCE", ex.getErrorCode());
    }

    @Test
    void shouldRejectPaymentToDraftInvoice() {
        Invoice draftInvoice = Invoice.builder()
                .orgId(orgId).status("DRAFT").invoiceNumber("INV-001")
                .totalAmount(new BigDecimal("1000.00"))
                .balanceDue(new BigDecimal("1000.00"))
                .build();
        draftInvoice.setId(UUID.randomUUID());

        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(draftInvoice.getId(), orgId))
                .thenReturn(Optional.of(draftInvoice));

        var request = new RecordPaymentRequest(
                draftInvoice.getId(),
                null,
                LocalDate.now(),
                new BigDecimal("500"), "CASH", null, null, null
        );

        BusinessException ex = assertThrows(BusinessException.class,
                () -> paymentService.recordPayment(request));
        assertEquals("AR_INVOICE_NOT_PAYABLE", ex.getErrorCode());
    }

    @Test
    void shouldUseCashAccountForUpiPayment() {
        Invoice invoice = Invoice.builder()
                .orgId(orgId).contactId(UUID.randomUUID())
                .invoiceNumber("INV-2026-000001").status("SENT")
                .totalAmount(new BigDecimal("500.00"))
                .amountPaid(BigDecimal.ZERO)
                .balanceDue(new BigDecimal("500.00"))
                .build();
        invoice.setId(UUID.randomUUID());

        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoice.getId(), orgId))
                .thenReturn(Optional.of(invoice));
        when(invoiceService.computeFiscalYear(any(LocalDate.class), anyInt())).thenReturn(2026);
        when(invoiceService.generateNumber(eq(orgId), eq("PAY"), anyInt()))
                .thenReturn("PAY-2026-000002");

        JournalEntry mockJournal = JournalEntry.builder().entryNumber("JE-2026-000003").build();
        mockJournal.setId(UUID.randomUUID());
        when(postingEngine.postPaymentReceived(any(), any(), any(), any(), any(), any()))
                .thenReturn(mockJournal);
        var request = new RecordPaymentRequest(
                invoice.getId(),
                null,
                LocalDate.now(), new BigDecimal("500"),
                "UPI", "UPI-REF-123", null, null
        );

        paymentService.recordPayment(request);

        verify(postingEngine).postPaymentReceived(
                eq(orgId), eq("PAY-2026-000002"), eq("INV-2026-000001"),
                any(LocalDate.class), eq(new BigDecimal("500")), eq("UPI"));
    }

    // ── recordForInvoice tests ──────────────────────────────────────────

    @Test
    void recordForInvoice_sentInvoice_returns201() {
        Invoice invoice = Invoice.builder()
                .orgId(orgId).contactId(UUID.randomUUID())
                .invoiceNumber("INV-2026-000001").status("SENT")
                .totalAmount(new BigDecimal("1000.00"))
                .amountPaid(BigDecimal.ZERO)
                .balanceDue(new BigDecimal("1000.00"))
                .build();
        invoice.setId(UUID.randomUUID());

        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoice.getId(), orgId))
                .thenReturn(Optional.of(invoice));
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(invoiceService.computeFiscalYear(any(LocalDate.class), anyInt())).thenReturn(2026);
        when(invoiceService.generateNumber(eq(orgId), eq("PAY"), anyInt()))
                .thenReturn("PAY-2026-000001");
        JournalEntry je = JournalEntry.builder().entryNumber("JE-001").build();
        je.setId(UUID.randomUUID());
        when(postingEngine.postPaymentReceived(any(), any(), any(), any(), any(), any()))
                .thenReturn(je);
        var req = new RecordPaymentForInvoiceRequest(
                new BigDecimal("500"), "BANK_TRANSFER",
                LocalDate.of(2026, 4, 18), null, "UTR-001", null);

        PaymentResponse response = paymentService.recordForInvoice(invoice.getId(), req);

        assertNotNull(response);
        assertEquals(0, new BigDecimal("500").compareTo(response.amount()));
        assertEquals("BANK_TRANSFER", response.paymentMethod());
        verify(invoiceService).updatePaymentStatus(invoice, new BigDecimal("500"));
    }

    @Test
    void recordPayment_rejectsWhenPendingApprovalAlreadyReservesBalance() {
        Invoice invoice = Invoice.builder()
                .orgId(orgId).contactId(UUID.randomUUID())
                .invoiceNumber("INV-PENDING-RESERVE").status("SENT")
                .totalAmount(new BigDecimal("1000.00"))
                .amountPaid(BigDecimal.ZERO)
                .balanceDue(new BigDecimal("1000.00"))
                .build();
        invoice.setId(UUID.randomUUID());

        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoice.getId(), orgId))
                .thenReturn(Optional.of(invoice));
        when(paymentRepository.sumPaymentsByInvoiceAndStatuses(eq(invoice.getId()), anyList()))
                .thenReturn(new BigDecimal("700.00"));

        var request = new RecordPaymentRequest(
                invoice.getId(),
                null,
                LocalDate.now(),
                new BigDecimal("400.00"),
                "CASH", null, null, null
        );

        BusinessException ex = assertThrows(BusinessException.class,
                () -> paymentService.recordPayment(request));

        assertEquals("AR_PAYMENT_EXCEEDS_BALANCE", ex.getErrorCode());
        verify(paymentRepository, never()).save(any(Payment.class));
        verify(postingEngine, never()).postPaymentReceived(any(), any(), any(), any(), any(), any());
    }

    @Test
    void postPayment_alreadyPosted_throwsBusinessException() {
        Payment payment = Payment.builder()
                .orgId(orgId)
                .contactId(UUID.randomUUID())
                .invoiceId(UUID.randomUUID())
                .paymentNumber("PAY-POSTED")
                .paymentDate(LocalDate.now())
                .amount(new BigDecimal("500"))
                .currency("INR")
                .baseAmount(new BigDecimal("500"))
                .paymentMethod("CASH")
                .status(com.katasticho.erp.ar.entity.PaymentStatus.POSTED)
                .build();
        payment.setId(UUID.randomUUID());
        savedPayments.put(payment.getId(), payment);

        BusinessException ex = assertThrows(BusinessException.class,
                () -> paymentService.postPayment(payment.getId()));

        assertEquals("AR_PAYMENT_ALREADY_POSTED", ex.getErrorCode());
        verify(postingEngine, never()).postPaymentReceived(any(), any(), any(), any(), any(), any());
        verify(invoiceService, never()).updatePaymentStatus(any(), any());
    }

    @Test
    void recordPayment_matchingWorkflow_setsPendingApprovalAndDoesNotPost() {
        Invoice invoice = Invoice.builder()
                .orgId(orgId).contactId(UUID.randomUUID())
                .invoiceNumber("INV-2026-000009").status("SENT")
                .totalAmount(new BigDecimal("75000.00"))
                .amountPaid(BigDecimal.ZERO)
                .balanceDue(new BigDecimal("75000.00"))
                .build();
        invoice.setId(UUID.randomUUID());

        WorkflowDefinition workflow = WorkflowDefinition.builder()
                .code("PAYMENT_HIGH_VALUE_APPROVAL")
                .name("Payment High Value Approval")
                .documentType("PAYMENT")
                .triggerCondition("{\"field\":\"payment.amount\",\"operator\":\"GT\",\"value\":50000}")
                .active(true)
                .build();
        workflow.setId(UUID.randomUUID());
        workflow.setOrgId(orgId);

        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoice.getId(), orgId))
                .thenReturn(Optional.of(invoice));
        when(invoiceService.computeFiscalYear(any(LocalDate.class), anyInt())).thenReturn(2026);
        when(invoiceService.generateNumber(eq(orgId), eq("PAY"), anyInt()))
                .thenReturn("PAY-2026-000009");
        when(approvalWorkflowService.findMatchingWorkflow(eq(orgId), eq("PAYMENT"), anyMap()))
                .thenReturn(Optional.of(workflow));

        var request = new RecordPaymentRequest(
                invoice.getId(),
                null,
                LocalDate.now(),
                new BigDecimal("75000"),
                "BANK_TRANSFER",
                "UTR-HIGH",
                "HDFC-001",
                "High value payment"
        );

        Payment result = paymentService.recordPayment(request);

        assertEquals(com.katasticho.erp.ar.entity.PaymentStatus.PENDING_APPROVAL, result.getStatus());
        assertNull(result.getJournalEntryId());
        assertNull(result.getPostedAt());

        verify(postingEngine, never()).postPaymentReceived(any(), any(), any(), any(), any(), any());
        verify(invoiceService, never()).updatePaymentStatus(any(), any());
        verify(approvalWorkflowService).requestApproval(
                eq(orgId),
                eq(workflow),
                eq("PAYMENT"),
                eq(result.getId()),
                contains("requires approval"),
                argThat(ctx -> new BigDecimal("75000").compareTo((BigDecimal) ctx.get("payment.amount")) == 0));
    }

    @Test
    void recordPayment_backdatedWorkflow_setsPendingApprovalAndDoesNotPost() {
        Invoice invoice = Invoice.builder()
                .orgId(orgId).contactId(UUID.randomUUID())
                .invoiceNumber("INV-2026-000010").status("SENT")
                .totalAmount(new BigDecimal("10000.00"))
                .amountPaid(BigDecimal.ZERO)
                .balanceDue(new BigDecimal("10000.00"))
                .build();
        invoice.setId(UUID.randomUUID());

        WorkflowDefinition workflow = WorkflowDefinition.builder()
                .code("PAYMENT_BACKDATED_APPROVAL")
                .name("Payment Backdated Approval")
                .documentType("PAYMENT")
                .triggerCondition("{\"field\":\"payment.daysBackdated\",\"operator\":\"GT\",\"value\":7}")
                .active(true)
                .build();
        workflow.setId(UUID.randomUUID());
        workflow.setOrgId(orgId);

        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoice.getId(), orgId))
                .thenReturn(Optional.of(invoice));
        when(invoiceService.computeFiscalYear(any(LocalDate.class), anyInt())).thenReturn(2026);
        when(invoiceService.generateNumber(eq(orgId), eq("PAY"), anyInt()))
                .thenReturn("PAY-2026-000010");
        when(approvalWorkflowService.findMatchingWorkflow(eq(orgId), eq("PAYMENT"), anyMap()))
                .thenReturn(Optional.of(workflow));

        var request = new RecordPaymentRequest(
                invoice.getId(),
                null,
                LocalDate.now().minusDays(10),
                new BigDecimal("5000"),
                "BANK_TRANSFER",
                "UTR-BACKDATED",
                "HDFC-001",
                "Backdated payment"
        );

        Payment result = paymentService.recordPayment(request);

        assertEquals(com.katasticho.erp.ar.entity.PaymentStatus.PENDING_APPROVAL, result.getStatus());
        assertNull(result.getJournalEntryId());
        assertNull(result.getPostedAt());

        verify(postingEngine, never()).postPaymentReceived(any(), any(), any(), any(), any(), any());
        verify(invoiceService, never()).updatePaymentStatus(any(), any());
        verify(approvalWorkflowService).requestApproval(
                eq(orgId),
                eq(workflow),
                eq("PAYMENT"),
                eq(result.getId()),
                contains("backdated"),
                argThat(ctx -> ((Long) ctx.get("payment.daysBackdated")) >= 10L));
    }

    @Test
    void postPayment_pendingApproval_postsJournalAndUpdatesInvoice() {
        UUID invoiceId = UUID.randomUUID();
        Invoice invoice = Invoice.builder()
                .orgId(orgId).contactId(UUID.randomUUID())
                .invoiceNumber("INV-2026-000011").status("SENT")
                .totalAmount(new BigDecimal("10000.00"))
                .amountPaid(BigDecimal.ZERO)
                .balanceDue(new BigDecimal("10000.00"))
                .build();
        invoice.setId(invoiceId);

        Payment payment = Payment.builder()
                .orgId(orgId)
                .contactId(invoice.getContactId())
                .invoiceId(invoiceId)
                .paymentNumber("PAY-PENDING")
                .paymentDate(LocalDate.now())
                .amount(new BigDecimal("5000"))
                .currency("INR")
                .baseAmount(new BigDecimal("5000"))
                .paymentMethod("BANK_TRANSFER")
                .status(com.katasticho.erp.ar.entity.PaymentStatus.PENDING_APPROVAL)
                .build();
        payment.setId(UUID.randomUUID());
        savedPayments.put(payment.getId(), payment);

        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(Optional.of(invoice));
        JournalEntry journal = JournalEntry.builder().entryNumber("JE-PAY-PENDING").status("POSTED").build();
        journal.setId(UUID.randomUUID());
        when(postingEngine.postPaymentReceived(any(), any(), any(), any(), any(), any()))
                .thenReturn(journal);

        Payment result = paymentService.postPayment(payment.getId());

        assertEquals(com.katasticho.erp.ar.entity.PaymentStatus.POSTED, result.getStatus());
        assertEquals(journal.getId(), result.getJournalEntryId());
        assertNotNull(result.getPostedAt());
        assertEquals(userId, result.getPostedBy());
        verify(documentStateEngine).validateTransition(
                eq(orgId), eq("PAYMENT"), eq("PENDING_APPROVAL"), eq("POSTED"));
        verify(postingEngine).postPaymentReceived(
                eq(orgId), eq("PAY-PENDING"), eq("INV-2026-000011"),
                eq(payment.getPaymentDate()), eq(new BigDecimal("5000")), eq("BANK_TRANSFER"));
        verify(invoiceService).updatePaymentStatus(invoice, new BigDecimal("5000"));
    }

    @Test
    void postPayment_pendingApprovalRejectsIfBalanceChangedBeforeApproval() {
        UUID invoiceId = UUID.randomUUID();
        Invoice invoice = Invoice.builder()
                .orgId(orgId).contactId(UUID.randomUUID())
                .invoiceNumber("INV-CHANGED-BAL").status("PARTIALLY_PAID")
                .totalAmount(new BigDecimal("10000.00"))
                .amountPaid(new BigDecimal("8000.00"))
                .balanceDue(new BigDecimal("2000.00"))
                .build();
        invoice.setId(invoiceId);

        Payment payment = Payment.builder()
                .orgId(orgId)
                .contactId(invoice.getContactId())
                .invoiceId(invoiceId)
                .paymentNumber("PAY-PENDING-TOO-MUCH")
                .paymentDate(LocalDate.now())
                .amount(new BigDecimal("5000.00"))
                .currency("INR")
                .baseAmount(new BigDecimal("5000.00"))
                .paymentMethod("BANK_TRANSFER")
                .status(com.katasticho.erp.ar.entity.PaymentStatus.PENDING_APPROVAL)
                .build();
        payment.setId(UUID.randomUUID());
        savedPayments.put(payment.getId(), payment);

        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(Optional.of(invoice));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> paymentService.postPayment(payment.getId()));

        assertEquals("AR_PAYMENT_EXCEEDS_BALANCE", ex.getErrorCode());
        verify(documentStateEngine).validateTransition(
                eq(orgId), eq("PAYMENT"), eq("PENDING_APPROVAL"), eq("POSTED"));
        verify(postingEngine, never()).postPaymentReceived(any(), any(), any(), any(), any(), any());
        verify(invoiceService, never()).updatePaymentStatus(any(), any());
    }

    @Test
    void voidPayment_postedPaymentReversesJournalAndBacksOutInvoiceBalance() {
        UUID invoiceId = UUID.randomUUID();
        UUID journalId = UUID.randomUUID();
        Invoice invoice = Invoice.builder()
                .orgId(orgId).contactId(UUID.randomUUID())
                .invoiceNumber("INV-VOID-POSTED").status("PAID")
                .totalAmount(new BigDecimal("1000.00"))
                .amountPaid(new BigDecimal("1000.00"))
                .balanceDue(BigDecimal.ZERO)
                .build();
        invoice.setId(invoiceId);

        Payment payment = Payment.builder()
                .orgId(orgId)
                .contactId(invoice.getContactId())
                .invoiceId(invoiceId)
                .paymentNumber("PAY-VOID-POSTED")
                .paymentDate(LocalDate.now())
                .amount(new BigDecimal("1000.00"))
                .currency("INR")
                .baseAmount(new BigDecimal("1000.00"))
                .paymentMethod("CASH")
                .journalEntryId(journalId)
                .status(com.katasticho.erp.ar.entity.PaymentStatus.POSTED)
                .build();
        payment.setId(UUID.randomUUID());
        savedPayments.put(payment.getId(), payment);

        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(Optional.of(invoice));

        Payment result = paymentService.voidPayment(payment.getId(), "Wrong receipt");

        assertEquals(com.katasticho.erp.ar.entity.PaymentStatus.VOIDED, result.getStatus());
        assertEquals("Wrong receipt", result.getVoidReason());
        assertNotNull(result.getVoidedAt());
        assertEquals(userId, result.getVoidedBy());
        verify(journalService).reverseEntry(journalId);
        verify(invoiceService).updatePaymentStatus(invoice, new BigDecimal("-1000.00"));
        verify(documentSnapshotService).createSnapshot(eq("PAYMENT"), eq(payment.getId()), eq("PAY-VOID-POSTED"), any());
    }

    @Test
    void voidPendingPayment_pendingApprovalVoidsWithoutPostingOrInvoiceUpdate() {
        UUID invoiceId = UUID.randomUUID();
        Payment payment = Payment.builder()
                .orgId(orgId)
                .contactId(UUID.randomUUID())
                .invoiceId(invoiceId)
                .paymentNumber("PAY-PENDING-VOID")
                .paymentDate(LocalDate.now())
                .amount(new BigDecimal("5000"))
                .currency("INR")
                .baseAmount(new BigDecimal("5000"))
                .paymentMethod("BANK_TRANSFER")
                .status(com.katasticho.erp.ar.entity.PaymentStatus.PENDING_APPROVAL)
                .build();
        payment.setId(UUID.randomUUID());
        savedPayments.put(payment.getId(), payment);

        Payment result = paymentService.voidPendingPayment(payment.getId(), "Approval rejected");

        assertEquals(com.katasticho.erp.ar.entity.PaymentStatus.VOIDED, result.getStatus());
        assertEquals("Approval rejected", result.getVoidReason());
        assertNotNull(result.getVoidedAt());
        assertEquals(userId, result.getVoidedBy());
        assertNull(result.getJournalEntryId());

        verify(documentStateEngine).validateTransition(
                eq(orgId), eq("PAYMENT"), eq("PENDING_APPROVAL"), eq("VOIDED"));
        verify(postingEngine, never()).postPaymentReceived(any(), any(), any(), any(), any(), any());
        verify(invoiceRepository, never()).findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId);
        verify(invoiceService, never()).updatePaymentStatus(any(), any());
    }

    @Test
    void recordForInvoice_amountExceedsBalance_throws400() {
        Invoice invoice = Invoice.builder()
                .orgId(orgId).contactId(UUID.randomUUID())
                .invoiceNumber("INV-001").status("SENT")
                .totalAmount(new BigDecimal("1000.00"))
                .amountPaid(BigDecimal.ZERO)
                .balanceDue(new BigDecimal("1000.00"))
                .build();
        invoice.setId(UUID.randomUUID());

        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoice.getId(), orgId))
                .thenReturn(Optional.of(invoice));

        var req = new RecordPaymentForInvoiceRequest(
                new BigDecimal("1500"), "CASH",
                LocalDate.now(), null, null, null);

        BusinessException ex = assertThrows(BusinessException.class,
                () -> paymentService.recordForInvoice(invoice.getId(), req));
        assertEquals("AR_PAYMENT_EXCEEDS_BALANCE", ex.getErrorCode());
        verify(paymentRepository, never()).save(any());
    }

    @Test
    void recordForInvoice_voidInvoice_throws400() {
        Invoice invoice = Invoice.builder()
                .orgId(orgId).contactId(UUID.randomUUID())
                .invoiceNumber("INV-001").status("CANCELLED")
                .totalAmount(new BigDecimal("1000.00"))
                .balanceDue(new BigDecimal("1000.00"))
                .build();
        invoice.setId(UUID.randomUUID());

        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoice.getId(), orgId))
                .thenReturn(Optional.of(invoice));

        var req = new RecordPaymentForInvoiceRequest(
                new BigDecimal("500"), "CASH",
                LocalDate.now(), null, null, null);

        BusinessException ex = assertThrows(BusinessException.class,
                () -> paymentService.recordForInvoice(invoice.getId(), req));
        assertEquals("AR_INVOICE_NOT_PAYABLE", ex.getErrorCode());
    }

    @Test
    void recordForInvoice_paidInvoice_throws400() {
        Invoice invoice = Invoice.builder()
                .orgId(orgId).contactId(UUID.randomUUID())
                .invoiceNumber("INV-001").status("PAID")
                .totalAmount(new BigDecimal("1000.00"))
                .amountPaid(new BigDecimal("1000.00"))
                .balanceDue(BigDecimal.ZERO)
                .build();
        invoice.setId(UUID.randomUUID());

        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoice.getId(), orgId))
                .thenReturn(Optional.of(invoice));

        var req = new RecordPaymentForInvoiceRequest(
                new BigDecimal("100"), "CASH",
                LocalDate.now(), null, null, null);

        BusinessException ex = assertThrows(BusinessException.class,
                () -> paymentService.recordForInvoice(invoice.getId(), req));
        assertEquals("AR_INVOICE_NOT_PAYABLE", ex.getErrorCode());
    }

    @Test
    void voidPostedPayment_restoresContactOutstandingAr() {
        UUID contactId = UUID.randomUUID();
        UUID invoiceId = UUID.randomUUID();

        Invoice invoice = Invoice.builder()
                .orgId(orgId).contactId(contactId)
                .invoiceNumber("INV-2026-000010").status("PAID")
                .totalAmount(new BigDecimal("1000.00"))
                .amountPaid(new BigDecimal("1000.00"))
                .balanceDue(BigDecimal.ZERO)
                .build();
        invoice.setId(invoiceId);

        Contact contact = new Contact();
        contact.setId(contactId);
        contact.setOutstandingAr(BigDecimal.ZERO);

        JournalEntry journal = JournalEntry.builder().entryNumber("JE-001").build();
        journal.setId(UUID.randomUUID());

        Payment payment = Payment.builder()
                .orgId(orgId).contactId(contactId).invoiceId(invoiceId)
                .paymentNumber("PAY-2026-000010")
                .paymentDate(LocalDate.of(2026, 5, 1))
                .amount(new BigDecimal("1000.00"))
                .currency("INR").paymentMethod("CASH")
                .status(com.katasticho.erp.ar.entity.PaymentStatus.POSTED)
                .build();
        payment.setId(UUID.randomUUID());
        payment.setJournalEntryId(journal.getId());
        savedPayments.put(payment.getId(), payment);

        when(invoiceRepository.findLockedByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(Optional.of(invoice));
        when(contactRepository.findById(contactId)).thenReturn(Optional.of(contact));
        when(contactRepository.save(any(Contact.class))).thenAnswer(inv -> inv.getArgument(0));

        paymentService.voidPayment(payment.getId(), "Test void");

        ArgumentCaptor<Contact> contactCaptor = ArgumentCaptor.forClass(Contact.class);
        verify(contactRepository).save(contactCaptor.capture());
        assertEquals(0, new BigDecimal("1000.00").compareTo(contactCaptor.getValue().getOutstandingAr()));

        assertEquals(com.katasticho.erp.ar.entity.PaymentStatus.VOIDED, payment.getStatus());
    }

    @Test
    void postPayment_decrementsContactOutstandingAr() {
        UUID contactId = UUID.randomUUID();

        Invoice invoice = Invoice.builder()
                .orgId(orgId).contactId(contactId)
                .invoiceNumber("INV-2026-000011").status("SENT")
                .totalAmount(new BigDecimal("500.00"))
                .amountPaid(BigDecimal.ZERO)
                .balanceDue(new BigDecimal("500.00"))
                .build();
        invoice.setId(UUID.randomUUID());

        Contact contact = new Contact();
        contact.setId(contactId);
        contact.setOutstandingAr(new BigDecimal("500.00"));

        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoice.getId(), orgId))
                .thenReturn(Optional.of(invoice));
        when(invoiceService.computeFiscalYear(any(LocalDate.class), anyInt())).thenReturn(2026);
        when(invoiceService.generateNumber(eq(orgId), eq("PAY"), anyInt()))
                .thenReturn("PAY-2026-000011");
        when(contactRepository.findById(contactId)).thenReturn(Optional.of(contact));
        when(contactRepository.save(any(Contact.class))).thenAnswer(inv -> inv.getArgument(0));

        JournalEntry mockJournal = JournalEntry.builder().entryNumber("JE-011").build();
        mockJournal.setId(UUID.randomUUID());
        when(postingEngine.postPaymentReceived(any(), any(), any(), any(), any(), any()))
                .thenReturn(mockJournal);

        paymentService.recordPayment(new RecordPaymentRequest(
                invoice.getId(), contactId, LocalDate.now(),
                new BigDecimal("500.00"), "CASH", null, null, null));

        ArgumentCaptor<Contact> captor = ArgumentCaptor.forClass(Contact.class);
        verify(contactRepository).save(captor.capture());
        assertEquals(0, BigDecimal.ZERO.compareTo(captor.getValue().getOutstandingAr()));
    }

    @Test
    void listForInvoice_returnsPaymentResponses() {
        UUID invoiceId = UUID.randomUUID();
        UUID contactId = UUID.randomUUID();

        Payment p1 = Payment.builder()
                .orgId(orgId).contactId(contactId).invoiceId(invoiceId)
                .paymentNumber("PAY-001").paymentDate(LocalDate.of(2026, 4, 10))
                .amount(new BigDecimal("500")).currency("INR")
                .paymentMethod("CASH").build();
        p1.setId(UUID.randomUUID());

        Payment p2 = Payment.builder()
                .orgId(orgId).contactId(contactId).invoiceId(invoiceId)
                .paymentNumber("PAY-002").paymentDate(LocalDate.of(2026, 4, 15))
                .amount(new BigDecimal("300")).currency("INR")
                .paymentMethod("UPI").build();
        p2.setId(UUID.randomUUID());

        when(paymentRepository.findByInvoiceIdAndIsDeletedFalse(invoiceId))
                .thenReturn(List.of(p1, p2));

        List<PaymentResponse> result = paymentService.listForInvoice(invoiceId);

        assertEquals(2, result.size());
        assertEquals("PAY-001", result.get(0).paymentNumber());
        assertEquals("PAY-002", result.get(1).paymentNumber());
    }
}
