package com.katasticho.erp.ar.service;

import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ar.dto.RecordPaymentRequest;
import com.katasticho.erp.ar.entity.Customer;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.Payment;
import com.katasticho.erp.ar.repository.CustomerRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.repository.PaymentRepository;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.currency.SimpleCurrencyService;
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
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PaymentServiceTest {

    @Mock private PaymentRepository paymentRepository;
    @Mock private InvoiceRepository invoiceRepository;
    @Mock private CustomerRepository customerRepository;
    @Mock private OrganisationRepository organisationRepository;
    @Mock private JournalService journalService;
    @Mock private InvoiceService invoiceService;
    @Mock private AuditService auditService;
    @Mock private CommentService commentService;

    private PaymentService paymentService;
    private UUID orgId;
    private UUID userId;
    private Organisation org;

    @BeforeEach
    void setUp() {
        paymentService = new PaymentService(
                paymentRepository, invoiceRepository, customerRepository,
                organisationRepository, journalService, invoiceService,
                new SimpleCurrencyService(), auditService, commentService);

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

    // T-AR-04: Payment posts correct journal (DR Cash, CR AR)
    @Test
    void shouldPostJournalOnPayment() {
        Invoice invoice = Invoice.builder()
                .orgId(orgId).customerId(UUID.randomUUID())
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
        when(journalService.postJournal(any(JournalPostRequest.class))).thenReturn(mockJournal);
        when(paymentRepository.save(any(Payment.class))).thenAnswer(inv -> {
            Payment p = inv.getArgument(0);
            if (p.getId() == null) p.setId(UUID.randomUUID());
            return p;
        });

        var request = new RecordPaymentRequest(
                invoice.getId(),
                null, // contactId — legacy test, derived from invoice
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

        // Verify journal: DR Bank (1020), CR AR (1200)
        ArgumentCaptor<JournalPostRequest> captor = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(captor.capture());

        JournalPostRequest journalReq = captor.getValue();
        assertEquals(2, journalReq.lines().size());
        assertEquals("1020", journalReq.lines().get(0).accountCode()); // Bank
        assertEquals(0, new BigDecimal("5000").compareTo(journalReq.lines().get(0).debit()));
        assertEquals("1200", journalReq.lines().get(1).accountCode()); // AR
        assertEquals(0, new BigDecimal("5000").compareTo(journalReq.lines().get(1).credit()));

        // Verify invoice payment status was updated
        verify(invoiceService).updatePaymentStatus(invoice, new BigDecimal("5000"));
    }

    // T-AR-04b: Payment exceeding balance should be rejected
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
                null, // contactId
                LocalDate.now(),
                new BigDecimal("1500"), // Exceeds balance
                "CASH", null, null, null
        );

        BusinessException ex = assertThrows(BusinessException.class,
                () -> paymentService.recordPayment(request));
        assertEquals("AR_PAYMENT_EXCEEDS_BALANCE", ex.getErrorCode());
    }

    // T-AR-04c: Payment to DRAFT invoice should be rejected
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
                null, // contactId
                LocalDate.now(),
                new BigDecimal("500"), "CASH", null, null, null
        );

        BusinessException ex = assertThrows(BusinessException.class,
                () -> paymentService.recordPayment(request));
        assertEquals("AR_INVOICE_NOT_PAYABLE", ex.getErrorCode());
    }

    // T-AR-04d: UPI payment should debit Cash account
    @Test
    void shouldUseCashAccountForUpiPayment() {
        Invoice invoice = Invoice.builder()
                .orgId(orgId).customerId(UUID.randomUUID())
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
        when(journalService.postJournal(any())).thenReturn(mockJournal);
        when(paymentRepository.save(any(Payment.class))).thenAnswer(inv -> {
            Payment p = inv.getArgument(0);
            if (p.getId() == null) p.setId(UUID.randomUUID());
            return p;
        });

        var request = new RecordPaymentRequest(
                invoice.getId(),
                null, // contactId
                LocalDate.now(), new BigDecimal("500"),
                "UPI", "UPI-REF-123", null, null
        );

        paymentService.recordPayment(request);

        ArgumentCaptor<JournalPostRequest> captor = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(captor.capture());
        assertEquals("1010", captor.getValue().lines().get(0).accountCode()); // Cash account for UPI
    }
}
