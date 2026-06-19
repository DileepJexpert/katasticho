package com.katasticho.erp.banking.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.ai.service.VisionModelRouter;
import com.katasticho.erp.ap.dto.VendorPaymentRequest;
import com.katasticho.erp.ap.dto.VendorPaymentResponse;
import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ap.service.VendorPaymentService;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.Payment;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.service.PaymentService;
import com.katasticho.erp.banking.dto.BankTransactionImportResponse;
import com.katasticho.erp.banking.dto.ImportBankTransactionsRequest;
import com.katasticho.erp.banking.entity.BankTransaction;
import com.katasticho.erp.banking.entity.PaymentMatch;
import com.katasticho.erp.banking.repository.BankTransactionRepository;
import com.katasticho.erp.banking.repository.PaymentMatchRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Pageable;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class BankReconciliationServiceTest {

    @Mock private BankTransactionRepository bankTransactionRepository;
    @Mock private PaymentMatchRepository paymentMatchRepository;
    @Mock private InvoiceRepository invoiceRepository;
    @Mock private PurchaseBillRepository purchaseBillRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private PaymentService paymentService;
    @Mock private VendorPaymentService vendorPaymentService;
    @Mock private DefaultAccountService defaultAccountService;
    @Mock private VisionModelRouter claudeApiClient;

    private BankReconciliationService service;
    private UUID orgId;
    private UUID userId;

    @BeforeEach
    void setUp() {
        service = new BankReconciliationService(
                bankTransactionRepository,
                paymentMatchRepository,
                invoiceRepository,
                purchaseBillRepository,
                contactRepository,
                paymentService,
                vendorPaymentService,
                defaultAccountService,
                new BankStatementParser(claudeApiClient, new ObjectMapper())
        );
        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void importCsv_createsSuggestedMatchForOutstandingInvoice() {
        UUID invoiceId = UUID.randomUUID();
        UUID contactId = UUID.randomUUID();

        Invoice invoice = Invoice.builder()
                .orgId(orgId)
                .contactId(contactId)
                .invoiceNumber("INV-2026-000011")
                .invoiceDate(LocalDate.of(2026, 5, 10))
                .balanceDue(new BigDecimal("1000.00"))
                .status("SENT")
                .build();
        invoice.setId(invoiceId);

        Contact contact = Contact.builder()
                .displayName("Rajesh Traders")
                .upiId("rajesh@upi")
                .build();
        contact.setId(contactId);

        when(bankTransactionRepository.existsByOrgIdAndUtrAndDirection(any(), any(), any()))
                .thenReturn(false);
        when(invoiceRepository.findOutstandingInvoicesForBankMatching(eq(orgId), eq(new BigDecimal("1000.00")), any(Pageable.class)))
                .thenReturn(List.of(invoice));
        when(contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), any()))
                .thenReturn(List.of(contact));
        when(invoiceRepository.findAllById(any())).thenReturn(List.of(invoice));
        when(bankTransactionRepository.save(any(BankTransaction.class))).thenAnswer(inv -> {
            BankTransaction tx = inv.getArgument(0);
            if (tx.getId() == null) {
                tx.setId(UUID.randomUUID());
            }
            if (tx.getCreatedAt() == null) {
                tx.setCreatedAt(Instant.now());
            }
            return tx;
        });
        when(paymentMatchRepository.saveAll(anyList())).thenAnswer(inv -> inv.getArgument(0));

        String csv = """
                date,amount,direction,narration,utr,payerName,payerVpa
                2026-05-14,1000,CREDIT,"Payment for INV-2026-000011",UTR123,Rajesh Traders,rajesh@upi
                """;

        BankTransactionImportResponse response = service.importCsv(new ImportBankTransactionsRequest(csv));

        assertEquals(1, response.imported());
        assertEquals(0, response.skipped());
        assertEquals(1, response.transactions().size());
        assertEquals("SUGGESTED", response.transactions().getFirst().status());
        assertEquals(1, response.transactions().getFirst().suggestedMatches().size());
        assertEquals(invoiceId, response.transactions().getFirst().suggestedMatches().getFirst().invoiceId());
    }

    @Test
    void acceptMatch_recordsPaymentAndMarksTransactionMatched() {
        UUID transactionId = UUID.randomUUID();
        UUID matchId = UUID.randomUUID();
        UUID invoiceId = UUID.randomUUID();
        UUID contactId = UUID.randomUUID();
        UUID paymentId = UUID.randomUUID();

        BankTransaction transaction = BankTransaction.builder()
                .orgId(orgId)
                .transactionDate(LocalDate.of(2026, 5, 14))
                .amount(new BigDecimal("850.00"))
                .direction("CREDIT")
                .narration("UPI from Rajesh")
                .utr("UTR-789")
                .payerVpa("rajesh@upi")
                .status("SUGGESTED")
                .build();
        transaction.setId(transactionId);
        transaction.setCreatedAt(Instant.now());

        PaymentMatch match = PaymentMatch.builder()
                .orgId(orgId)
                .bankTransactionId(transactionId)
                .invoiceId(invoiceId)
                .contactId(contactId)
                .matchedAmount(new BigDecimal("850.00"))
                .confidence(new BigDecimal("0.9200"))
                .matchStatus("SUGGESTED")
                .build();
        match.setId(matchId);

        Invoice invoice = Invoice.builder()
                .orgId(orgId)
                .contactId(contactId)
                .invoiceNumber("INV-2026-000020")
                .balanceDue(new BigDecimal("850.00"))
                .status("SENT")
                .build();
        invoice.setId(invoiceId);

        Contact contact = Contact.builder().displayName("Rajesh").build();
        contact.setId(contactId);

        Payment payment = Payment.builder()
                .paymentNumber("PAY-2026-000099")
                .build();
        payment.setId(paymentId);

        when(paymentMatchRepository.findByIdAndOrgId(matchId, orgId)).thenReturn(Optional.of(match));
        when(bankTransactionRepository.findByIdAndOrgId(transactionId, orgId)).thenReturn(Optional.of(transaction));
        when(paymentService.recordPayment(any())).thenReturn(payment);
        when(paymentMatchRepository.findByOrgIdAndBankTransactionIdOrderByConfidenceDesc(orgId, transactionId))
                .thenReturn(List.of(match));
        when(invoiceRepository.findAllById(any())).thenReturn(List.of(invoice));
        when(contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), any()))
                .thenReturn(List.of(contact));
        when(bankTransactionRepository.save(any(BankTransaction.class))).thenAnswer(inv -> inv.getArgument(0));
        when(paymentMatchRepository.save(any(PaymentMatch.class))).thenAnswer(inv -> inv.getArgument(0));
        when(paymentMatchRepository.saveAll(anyList())).thenAnswer(inv -> inv.getArgument(0));

        var response = service.acceptMatch(matchId);

        assertEquals("MATCHED", response.status());
        assertEquals(paymentId, response.paymentId());
        assertEquals("ACCEPTED", response.suggestedMatches().getFirst().matchStatus());

        ArgumentCaptor<com.katasticho.erp.ar.dto.RecordPaymentRequest> captor =
                ArgumentCaptor.forClass(com.katasticho.erp.ar.dto.RecordPaymentRequest.class);
        verify(paymentService).recordPayment(captor.capture());
        assertEquals(invoiceId, captor.getValue().invoiceId());
        assertEquals("UPI", captor.getValue().paymentMethod());
        assertEquals("UTR-789", captor.getValue().referenceNumber());
    }

    // ── Debit side (vendor bills) — Phase E ─────────────────────────────

    @Test
    void importCsv_debitTransactionSuggestsOpenBillMatch() {
        UUID billId = UUID.randomUUID();
        UUID vendorId = UUID.randomUUID();

        PurchaseBill bill = PurchaseBill.builder()
                .id(billId)
                .orgId(orgId)
                .contactId(vendorId)
                .billNumber("BILL-2026-0009")
                .vendorBillNumber("INV-77")
                .billDate(LocalDate.of(2026, 4, 1))
                .totalAmount(new BigDecimal("22000.00"))
                .balanceDue(new BigDecimal("22000.00"))
                .status("OPEN")
                .build();

        Contact vendor = Contact.builder().displayName("ABC Pharma Supplies").build();
        vendor.setId(vendorId);

        when(bankTransactionRepository.existsByOrgIdAndUtrAndDirection(any(), any(), any()))
                .thenReturn(false);
        when(purchaseBillRepository.findOutstandingBillsForBankMatching(
                eq(orgId), eq(new BigDecimal("22000.00")), any(Pageable.class)))
                .thenReturn(List.of(bill));
        when(purchaseBillRepository.findAllById(any())).thenReturn(List.of(bill));
        when(contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), any()))
                .thenReturn(List.of(vendor));
        when(bankTransactionRepository.save(any(BankTransaction.class))).thenAnswer(inv -> {
            BankTransaction tx = inv.getArgument(0);
            if (tx.getId() == null) tx.setId(UUID.randomUUID());
            if (tx.getCreatedAt() == null) tx.setCreatedAt(Instant.now());
            return tx;
        });
        when(paymentMatchRepository.saveAll(anyList())).thenAnswer(inv -> inv.getArgument(0));

        String csv = """
                date,amount,direction,narration,utr
                2026-04-05,22000,DEBIT,NEFT-ABC PHARMA SUPPLIES-INV-77,NEFT000123
                """;

        BankTransactionImportResponse response = service.importCsv(new ImportBankTransactionsRequest(csv));

        assertEquals(1, response.transactions().size());
        var tx = response.transactions().getFirst();
        assertEquals("SUGGESTED", tx.status());
        assertEquals(1, tx.suggestedMatches().size());
        var match = tx.suggestedMatches().getFirst();
        assertEquals("BILL", match.matchType());
        assertEquals(billId, match.billId());
        assertEquals("INV-77", match.documentNumber());
        // Exact amount + vendor bill number + vendor name in narration → high confidence.
        assertTrue(match.confidence().compareTo(new BigDecimal("0.9")) > 0);
    }

    @Test
    void acceptMatch_billMatchRecordsVendorPayment() {
        UUID transactionId = UUID.randomUUID();
        UUID matchId = UUID.randomUUID();
        UUID billId = UUID.randomUUID();
        UUID vendorId = UUID.randomUUID();
        UUID bankAccountId = UUID.randomUUID();
        UUID vendorPaymentId = UUID.randomUUID();

        BankTransaction transaction = BankTransaction.builder()
                .orgId(orgId)
                .transactionDate(LocalDate.of(2026, 4, 5))
                .amount(new BigDecimal("22000.00"))
                .direction("DEBIT")
                .narration("NEFT-ABC PHARMA")
                .utr("NEFT000123")
                .status("SUGGESTED")
                .build();
        transaction.setId(transactionId);
        transaction.setCreatedAt(Instant.now());

        PaymentMatch match = PaymentMatch.builder()
                .orgId(orgId)
                .bankTransactionId(transactionId)
                .matchType("BILL")
                .billId(billId)
                .contactId(vendorId)
                .matchedAmount(new BigDecimal("22000.00"))
                .confidence(new BigDecimal("0.9500"))
                .matchStatus("SUGGESTED")
                .build();
        match.setId(matchId);

        PurchaseBill bill = PurchaseBill.builder()
                .id(billId).orgId(orgId).contactId(vendorId)
                .billNumber("BILL-2026-0009").vendorBillNumber("INV-77")
                .billDate(LocalDate.of(2026, 4, 1))
                .totalAmount(new BigDecimal("22000.00"))
                .balanceDue(new BigDecimal("22000.00"))
                .status("OPEN").build();

        Contact vendor = Contact.builder().displayName("ABC Pharma Supplies").build();
        vendor.setId(vendorId);

        Account bankAccount = Account.builder()
                .code("1020").name("Bank Account").type("ASSET").build();
        bankAccount.setId(bankAccountId);

        VendorPaymentResponse vendorPayment = mock(VendorPaymentResponse.class);
        when(vendorPayment.id()).thenReturn(vendorPaymentId);

        when(paymentMatchRepository.findByIdAndOrgId(matchId, orgId)).thenReturn(Optional.of(match));
        when(bankTransactionRepository.findByIdAndOrgId(transactionId, orgId)).thenReturn(Optional.of(transaction));
        when(defaultAccountService.get(orgId, DefaultAccountPurpose.BANK)).thenReturn(bankAccount);
        when(vendorPaymentService.recordPayment(any(VendorPaymentRequest.class))).thenReturn(vendorPayment);
        when(paymentMatchRepository.findByOrgIdAndBankTransactionIdOrderByConfidenceDesc(orgId, transactionId))
                .thenReturn(List.of(match));
        when(purchaseBillRepository.findAllById(any())).thenReturn(List.of(bill));
        when(contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), any()))
                .thenReturn(List.of(vendor));
        when(bankTransactionRepository.save(any(BankTransaction.class))).thenAnswer(inv -> inv.getArgument(0));
        when(paymentMatchRepository.save(any(PaymentMatch.class))).thenAnswer(inv -> inv.getArgument(0));
        when(paymentMatchRepository.saveAll(anyList())).thenAnswer(inv -> inv.getArgument(0));

        var response = service.acceptMatch(matchId);

        ArgumentCaptor<VendorPaymentRequest> captor = ArgumentCaptor.forClass(VendorPaymentRequest.class);
        verify(vendorPaymentService).recordPayment(captor.capture());
        VendorPaymentRequest req = captor.getValue();
        assertEquals(vendorId, req.contactId());
        assertEquals(0, req.amount().compareTo(new BigDecimal("22000.00")));
        assertEquals(bankAccountId, req.paidThroughId());
        assertEquals(1, req.allocations().size());
        assertEquals(billId, req.allocations().getFirst().billId());

        assertEquals("MATCHED", response.status());
        assertEquals(vendorPaymentId, response.paymentId());
        assertEquals("ACCEPTED", match.getMatchStatus());
        assertEquals(vendorPaymentId, match.getPaymentId());
        verify(paymentService, never()).recordPayment(any());
    }
}
