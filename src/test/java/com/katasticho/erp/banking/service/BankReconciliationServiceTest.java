package com.katasticho.erp.banking.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ai.service.VisionModelRouter;
import com.katasticho.erp.banking.entity.BankRule;
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
    @Mock private BankAccountService bankAccountService;
    @Mock private BankRuleService bankRuleService;
    @Mock private JournalService journalService;
    @Mock private AccountRepository accountRepository;
    @Mock private com.katasticho.erp.accounting.repository.FiscalPeriodRepository fiscalPeriodRepository;
    @Mock private com.katasticho.erp.organisation.OrganisationRepository organisationRepository;
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
                new BankStatementParser(claudeApiClient, new ObjectMapper()),
                bankAccountService,
                bankRuleService,
                journalService,
                accountRepository,
                fiscalPeriodRepository,
                organisationRepository
        );
        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
        // Default: no bank rule matches, so the existing invoice/bill scoring runs.
        lenient().when(bankRuleService.firstMatch(any(), any())).thenReturn(Optional.empty());
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

        when(bankTransactionRepository.existsByOrgIdAndUtrAndDirectionAndTransactionDateAndAmount(any(), any(), any(), any(), any()))
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
        when(bankTransactionRepository.findByIdAndOrgIdForUpdate(transactionId, orgId)).thenReturn(Optional.of(transaction));
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

        when(bankTransactionRepository.existsByOrgIdAndUtrAndDirectionAndTransactionDateAndAmount(any(), any(), any(), any(), any()))
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
        when(bankTransactionRepository.findByIdAndOrgIdForUpdate(transactionId, orgId)).thenReturn(Optional.of(transaction));
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

    // ── Bank rules (ACCOUNT categorisation) — H4 ────────────────────────────

    private BankRule rule(String accountCode, boolean autoApply) {
        BankRule r = BankRule.builder()
                .name("Test rule").priority(100).active(true)
                .directionFilter("ANY").narrationOp("CONTAINS").narrationValue("x")
                .amountOp("ANY").accountCode(accountCode).autoApply(autoApply)
                .build();
        r.setId(UUID.randomUUID());
        r.setOrgId(orgId);
        return r;
    }

    @Test
    void importCsv_ruleMatch_autoApply_closedPeriod_fallsBackToSuggestedNotAbort() {
        // A closed-period auto-apply must degrade to a suggestion, NOT poison the
        // whole import tx (the same-bean fiscal-period guard throws without marking
        // the outer tx rollback-only).
        BankRule r = rule("5230", true);
        UUID acctMatchId = UUID.randomUUID();
        java.util.concurrent.atomic.AtomicReference<PaymentMatch> saved = new java.util.concurrent.atomic.AtomicReference<>();
        java.util.concurrent.atomic.AtomicReference<BankTransaction> savedTx = new java.util.concurrent.atomic.AtomicReference<>();
        Account bank = Account.builder().code("1020").name("Bank").type("ASSET").build();
        Account charges = Account.builder().code("5230").name("Bank Charges").type("EXPENSE").build();

        when(bankRuleService.firstMatch(eq(orgId), any(BankTransaction.class))).thenReturn(Optional.of(r));
        when(bankTransactionRepository.existsByOrgIdAndUtrAndDirectionAndTransactionDateAndAmount(any(), any(), any(), any(), any())).thenReturn(false);
        when(bankTransactionRepository.save(any(BankTransaction.class))).thenAnswer(inv -> {
            BankTransaction tx = inv.getArgument(0);
            if (tx.getId() == null) tx.setId(UUID.randomUUID());
            if (tx.getCreatedAt() == null) tx.setCreatedAt(Instant.now());
            savedTx.set(tx);
            return tx;
        });
        when(paymentMatchRepository.save(any(PaymentMatch.class))).thenAnswer(inv -> {
            PaymentMatch m = inv.getArgument(0);
            if (m.getId() == null) m.setId(acctMatchId);
            saved.set(m);
            return m;
        });
        when(paymentMatchRepository.findByIdAndOrgId(eq(acctMatchId), eq(orgId)))
                .thenAnswer(inv -> Optional.of(saved.get()));
        when(bankTransactionRepository.findByIdAndOrgIdForUpdate(any(), eq(orgId)))
                .thenAnswer(inv -> Optional.ofNullable(savedTx.get()));
        when(defaultAccountService.get(orgId, DefaultAccountPurpose.BANK)).thenReturn(bank);
        when(accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, "5230"))
                .thenReturn(Optional.of(charges)); // account exists — it's the PERIOD that's closed
        when(fiscalPeriodRepository.findByOrgIdAndPeriodYearAndPeriodMonth(eq(orgId), anyInt(), anyInt()))
                .thenReturn(Optional.of(com.katasticho.erp.accounting.entity.FiscalPeriod.builder()
                        .orgId(orgId).periodYear(2026).periodMonth(5).status("CLOSED").build()));

        String csv = """
                date,amount,direction,narration,utr
                2026-05-20,150,DEBIT,MONTHLY BANK CHARGES,REF-9
                """;
        BankTransactionImportResponse response = service.importCsv(new ImportBankTransactionsRequest(csv));

        assertEquals(1, response.imported());
        assertEquals("SUGGESTED", response.transactions().getFirst().status());
        verify(journalService, never()).postJournal(any());
    }

    @Test
    void ignoreTransaction_onMatchedTransaction_rejected() {
        // A settled (MATCHED / payment-posted) transaction must not be flippable
        // to IGNORED — otherwise ignore → rerun → accept re-posts the same money.
        BankTransaction tx = accountTx("CREDIT", new BigDecimal("5000.00"));
        tx.setStatus("MATCHED");
        tx.setPaymentId(UUID.randomUUID());
        when(bankTransactionRepository.findByIdAndOrgId(tx.getId(), orgId)).thenReturn(Optional.of(tx));

        var ex = assertThrows(com.katasticho.erp.common.exception.BusinessException.class,
                () -> service.ignoreTransaction(tx.getId()));
        assertEquals("BANK_TX_ALREADY_MATCHED", ex.getErrorCode());
        verify(bankTransactionRepository, never()).save(any());
    }

    @Test
    void import_sameReferenceDifferentAmount_bothImport_trueDuplicateSkipped() {
        // Dedupe on the full identity: a repeated reference with a different amount
        // (NACH/EMI, split charge+GST) must import; only an identical re-import
        // (same ref+date+amount+direction) is a duplicate.
        when(bankTransactionRepository.existsByOrgIdAndUtrAndDirectionAndTransactionDateAndAmount(
                eq(orgId), eq("UMRN1"), eq("DEBIT"), any(), eq(new BigDecimal("15000.00"))))
                .thenReturn(false);
        when(bankTransactionRepository.existsByOrgIdAndUtrAndDirectionAndTransactionDateAndAmount(
                eq(orgId), eq("UMRN1"), eq("DEBIT"), any(), eq(new BigDecimal("18000.00"))))
                .thenReturn(false);
        when(bankTransactionRepository.save(any(BankTransaction.class))).thenAnswer(inv -> {
            BankTransaction tx = inv.getArgument(0);
            if (tx.getId() == null) tx.setId(UUID.randomUUID());
            if (tx.getCreatedAt() == null) tx.setCreatedAt(Instant.now());
            return tx;
        });
        when(purchaseBillRepository.findOutstandingBillsForBankMatching(any(), any(), any())).thenReturn(List.of());

        String csv = """
                date,amount,direction,narration,utr
                2026-05-10,15000,DEBIT,EMI mandate,UMRN1
                2026-06-10,18000,DEBIT,EMI mandate,UMRN1
                """;
        BankTransactionImportResponse response = service.importCsv(new ImportBankTransactionsRequest(csv));

        assertEquals(2, response.imported());
        assertEquals(0, response.skipped());
    }

    private BankTransaction accountTx(String direction, BigDecimal amount) {
        BankTransaction tx = BankTransaction.builder()
                .orgId(orgId).transactionDate(LocalDate.of(2026, 5, 20))
                .amount(amount).direction(direction).narration("BANK CHARGES")
                .utr("REF-1").status("UNMATCHED").build();
        tx.setId(UUID.randomUUID());
        tx.setCreatedAt(Instant.now());
        return tx;
    }

    private void stubJournal(UUID journalId) {
        JournalEntry entry = mock(JournalEntry.class);
        when(entry.getId()).thenReturn(journalId);
        when(journalService.postJournal(any(JournalPostRequest.class))).thenReturn(entry);
    }

    @Test
    void acceptMatch_accountCredit_postsDrBankCrAccount() {
        UUID matchId = UUID.randomUUID();
        UUID journalId = UUID.randomUUID();
        BankTransaction tx = accountTx("CREDIT", new BigDecimal("500.00"));
        PaymentMatch match = PaymentMatch.builder()
                .orgId(orgId).bankTransactionId(tx.getId()).matchType("ACCOUNT")
                .accountCode("4110").bankRuleId(UUID.randomUUID())
                .matchedAmount(new BigDecimal("500.00")).confidence(new BigDecimal("0.9900"))
                .matchStatus("SUGGESTED").build();
        match.setId(matchId);
        Account bank = Account.builder().code("1020").name("Bank").type("ASSET").build();
        Account income = Account.builder().code("4110").name("Interest Income").type("INCOME").build();

        when(paymentMatchRepository.findByIdAndOrgId(matchId, orgId)).thenReturn(Optional.of(match));
        when(bankTransactionRepository.findByIdAndOrgIdForUpdate(tx.getId(), orgId)).thenReturn(Optional.of(tx));
        when(accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, "4110")).thenReturn(Optional.of(income));
        when(defaultAccountService.get(orgId, DefaultAccountPurpose.BANK)).thenReturn(bank);
        when(bankRuleService.findEntity(eq(orgId), any())).thenReturn(Optional.empty());
        stubJournal(journalId);
        when(paymentMatchRepository.findByOrgIdAndBankTransactionIdOrderByConfidenceDesc(orgId, tx.getId()))
                .thenReturn(List.of(match));
        when(bankTransactionRepository.save(any(BankTransaction.class))).thenAnswer(inv -> inv.getArgument(0));
        when(paymentMatchRepository.save(any(PaymentMatch.class))).thenAnswer(inv -> inv.getArgument(0));
        when(paymentMatchRepository.saveAll(anyList())).thenAnswer(inv -> inv.getArgument(0));

        var response = service.acceptMatch(matchId);

        assertEquals("MATCHED", response.status());
        assertEquals(journalId, response.paymentId());
        ArgumentCaptor<JournalPostRequest> captor = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(captor.capture());
        List<JournalLineRequest> lines = captor.getValue().lines();
        assertEquals("1020", lines.get(0).accountCode());     // DR bank
        assertEquals(0, lines.get(0).debit().compareTo(new BigDecimal("500.00")));
        assertEquals("4110", lines.get(1).accountCode());     // CR account
        assertEquals(0, lines.get(1).credit().compareTo(new BigDecimal("500.00")));
        assertTrue(captor.getValue().autoPost());
        verify(paymentService, never()).recordPayment(any());
        verify(vendorPaymentService, never()).recordPayment(any());
    }

    @Test
    void acceptMatch_accountDebit_postsDrAccountCrBank() {
        UUID matchId = UUID.randomUUID();
        BankTransaction tx = accountTx("DEBIT", new BigDecimal("120.00"));
        PaymentMatch match = PaymentMatch.builder()
                .orgId(orgId).bankTransactionId(tx.getId()).matchType("ACCOUNT")
                .accountCode("5230").bankRuleId(UUID.randomUUID())
                .matchedAmount(new BigDecimal("120.00")).confidence(new BigDecimal("0.9900"))
                .matchStatus("SUGGESTED").build();
        match.setId(matchId);
        Account bank = Account.builder().code("1020").name("Bank").type("ASSET").build();
        Account charges = Account.builder().code("5230").name("Bank Charges").type("EXPENSE").build();

        when(paymentMatchRepository.findByIdAndOrgId(matchId, orgId)).thenReturn(Optional.of(match));
        when(bankTransactionRepository.findByIdAndOrgIdForUpdate(tx.getId(), orgId)).thenReturn(Optional.of(tx));
        when(accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, "5230")).thenReturn(Optional.of(charges));
        when(defaultAccountService.get(orgId, DefaultAccountPurpose.BANK)).thenReturn(bank);
        when(bankRuleService.findEntity(eq(orgId), any())).thenReturn(Optional.empty());
        stubJournal(UUID.randomUUID());
        when(paymentMatchRepository.findByOrgIdAndBankTransactionIdOrderByConfidenceDesc(orgId, tx.getId()))
                .thenReturn(List.of(match));
        when(bankTransactionRepository.save(any(BankTransaction.class))).thenAnswer(inv -> inv.getArgument(0));
        when(paymentMatchRepository.save(any(PaymentMatch.class))).thenAnswer(inv -> inv.getArgument(0));
        when(paymentMatchRepository.saveAll(anyList())).thenAnswer(inv -> inv.getArgument(0));

        service.acceptMatch(matchId);

        ArgumentCaptor<JournalPostRequest> captor = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(captor.capture());
        List<JournalLineRequest> lines = captor.getValue().lines();
        assertEquals("5230", lines.get(0).accountCode());     // DR account (expense)
        assertEquals(0, lines.get(0).debit().compareTo(new BigDecimal("120.00")));
        assertEquals("1020", lines.get(1).accountCode());     // CR bank
        assertEquals(0, lines.get(1).credit().compareTo(new BigDecimal("120.00")));
    }

    @Test
    void acceptMatch_accountMissingTargetAccount_throws() {
        UUID matchId = UUID.randomUUID();
        BankTransaction tx = accountTx("DEBIT", new BigDecimal("120.00"));
        PaymentMatch match = PaymentMatch.builder()
                .orgId(orgId).bankTransactionId(tx.getId()).matchType("ACCOUNT")
                .accountCode("9999").matchedAmount(new BigDecimal("120.00"))
                .confidence(new BigDecimal("0.9900")).matchStatus("SUGGESTED").build();
        match.setId(matchId);
        Account bank = Account.builder().code("1020").name("Bank").type("ASSET").build();

        when(paymentMatchRepository.findByIdAndOrgId(matchId, orgId)).thenReturn(Optional.of(match));
        when(bankTransactionRepository.findByIdAndOrgIdForUpdate(tx.getId(), orgId)).thenReturn(Optional.of(tx));
        when(accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, "9999")).thenReturn(Optional.empty());
        when(defaultAccountService.get(orgId, DefaultAccountPurpose.BANK)).thenReturn(bank);

        var ex = assertThrows(com.katasticho.erp.common.exception.BusinessException.class,
                () -> service.acceptMatch(matchId));
        assertEquals("BANK_RULE_ACCOUNT_MISSING", ex.getErrorCode());
        verify(journalService, never()).postJournal(any());
    }

    @Test
    void importCsv_ruleMatch_noAutoApply_suggestsAccountMatch() {
        BankRule r = rule("5230", false);
        when(bankRuleService.firstMatch(eq(orgId), any(BankTransaction.class))).thenReturn(Optional.of(r));
        when(bankTransactionRepository.existsByOrgIdAndUtrAndDirectionAndTransactionDateAndAmount(any(), any(), any(), any(), any())).thenReturn(false);
        when(bankTransactionRepository.save(any(BankTransaction.class))).thenAnswer(inv -> {
            BankTransaction tx = inv.getArgument(0);
            if (tx.getId() == null) tx.setId(UUID.randomUUID());
            if (tx.getCreatedAt() == null) tx.setCreatedAt(Instant.now());
            return tx;
        });
        when(paymentMatchRepository.save(any(PaymentMatch.class))).thenAnswer(inv -> {
            PaymentMatch m = inv.getArgument(0);
            if (m.getId() == null) m.setId(UUID.randomUUID());
            return m;
        });

        String csv = """
                date,amount,direction,narration,utr
                2026-05-20,150,DEBIT,MONTHLY BANK CHARGES,REF-9
                """;
        BankTransactionImportResponse response = service.importCsv(new ImportBankTransactionsRequest(csv));

        var tx = response.transactions().getFirst();
        assertEquals("SUGGESTED", tx.status());
        assertEquals(1, tx.suggestedMatches().size());
        assertEquals("ACCOUNT", tx.suggestedMatches().getFirst().matchType());
        assertEquals("5230", tx.suggestedMatches().getFirst().documentNumber());
        verify(journalService, never()).postJournal(any());     // suggest only, no posting
        verify(invoiceRepository, never()).findOutstandingInvoicesForBankMatching(any(), any(), any());
    }

    @Test
    void importCsv_ruleMatch_autoApply_postsJournalAndMarksMatched() {
        BankRule r = rule("5230", true);
        UUID journalId = UUID.randomUUID();
        UUID acctMatchId = UUID.randomUUID();
        java.util.concurrent.atomic.AtomicReference<PaymentMatch> saved = new java.util.concurrent.atomic.AtomicReference<>();
        java.util.concurrent.atomic.AtomicReference<BankTransaction> savedTx = new java.util.concurrent.atomic.AtomicReference<>();
        Account bank = Account.builder().code("1020").name("Bank").type("ASSET").build();
        Account charges = Account.builder().code("5230").name("Bank Charges").type("EXPENSE").build();

        when(bankRuleService.firstMatch(eq(orgId), any(BankTransaction.class))).thenReturn(Optional.of(r));
        when(bankRuleService.findEntity(eq(orgId), any())).thenReturn(Optional.of(r));
        when(bankTransactionRepository.existsByOrgIdAndUtrAndDirectionAndTransactionDateAndAmount(any(), any(), any(), any(), any())).thenReturn(false);
        when(bankTransactionRepository.save(any(BankTransaction.class))).thenAnswer(inv -> {
            BankTransaction tx = inv.getArgument(0);
            if (tx.getId() == null) tx.setId(UUID.randomUUID());
            if (tx.getCreatedAt() == null) tx.setCreatedAt(Instant.now());
            savedTx.set(tx);
            return tx;
        });
        when(paymentMatchRepository.save(any(PaymentMatch.class))).thenAnswer(inv -> {
            PaymentMatch m = inv.getArgument(0);
            if (m.getId() == null) m.setId(acctMatchId);
            saved.set(m);
            return m;
        });
        when(paymentMatchRepository.findByIdAndOrgId(eq(acctMatchId), eq(orgId)))
                .thenAnswer(inv -> Optional.of(saved.get()));
        when(bankTransactionRepository.findByIdAndOrgIdForUpdate(any(), eq(orgId)))
                .thenAnswer(inv -> Optional.ofNullable(savedTx.get()));
        when(accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, "5230")).thenReturn(Optional.of(charges));
        when(defaultAccountService.get(orgId, DefaultAccountPurpose.BANK)).thenReturn(bank);
        stubJournal(journalId);
        when(paymentMatchRepository.findByOrgIdAndBankTransactionIdOrderByConfidenceDesc(eq(orgId), any()))
                .thenAnswer(inv -> List.of(saved.get()));

        String csv = """
                date,amount,direction,narration,utr
                2026-05-20,150,DEBIT,MONTHLY BANK CHARGES,REF-9
                """;
        BankTransactionImportResponse response = service.importCsv(new ImportBankTransactionsRequest(csv));

        assertEquals("MATCHED", response.transactions().getFirst().status());
        verify(journalService).postJournal(any(JournalPostRequest.class));
    }

    // ── Review-fix regressions ─────────────────────────────────────────────

    @Test
    void acceptMatch_nonSuggestedMatch_rejected() {
        UUID matchId = UUID.randomUUID();
        PaymentMatch match = PaymentMatch.builder()
                .orgId(orgId).bankTransactionId(UUID.randomUUID()).matchType("ACCOUNT")
                .accountCode("5230").matchedAmount(new BigDecimal("100.00"))
                .confidence(new BigDecimal("0.9900")).matchStatus("ACCEPTED").build();
        match.setId(matchId);
        when(paymentMatchRepository.findByIdAndOrgId(matchId, orgId)).thenReturn(Optional.of(match));

        var ex = assertThrows(com.katasticho.erp.common.exception.BusinessException.class,
                () -> service.acceptMatch(matchId));
        assertEquals("BANK_MATCH_NOT_SUGGESTED", ex.getErrorCode());
        verify(journalService, never()).postJournal(any());
        verify(bankTransactionRepository, never()).findByIdAndOrgIdForUpdate(any(), any());
    }

    @Test
    void rerunMatches_onMatchedTransaction_rejected() {
        BankTransaction tx = accountTx("DEBIT", new BigDecimal("120.00"));
        tx.setStatus("MATCHED");
        when(bankTransactionRepository.findByIdAndOrgId(tx.getId(), orgId)).thenReturn(Optional.of(tx));

        var ex = assertThrows(com.katasticho.erp.common.exception.BusinessException.class,
                () -> service.rerunMatches(tx.getId()));
        assertEquals("BANK_TX_ALREADY_MATCHED", ex.getErrorCode());
        verify(paymentMatchRepository, never())
                .deleteByOrgIdAndBankTransactionIdAndMatchStatus(any(), any(), any());
    }

    @Test
    void importCsv_ruleMatch_autoApply_noReference_fallsBackToSuggested() {
        BankRule r = rule("5230", true);
        when(bankRuleService.firstMatch(eq(orgId), any(BankTransaction.class))).thenReturn(Optional.of(r));
        when(bankTransactionRepository.save(any(BankTransaction.class))).thenAnswer(inv -> {
            BankTransaction tx = inv.getArgument(0);
            if (tx.getId() == null) tx.setId(UUID.randomUUID());
            if (tx.getCreatedAt() == null) tx.setCreatedAt(Instant.now());
            return tx;
        });
        when(paymentMatchRepository.save(any(PaymentMatch.class))).thenAnswer(inv -> {
            PaymentMatch m = inv.getArgument(0);
            if (m.getId() == null) m.setId(UUID.randomUUID());
            return m;
        });
        // NO utr column → reference is null → auto-apply must NOT post (re-import safety)
        String csv = """
                date,amount,direction,narration
                2026-05-20,150,DEBIT,MONTHLY BANK CHARGES
                """;
        BankTransactionImportResponse response = service.importCsv(new ImportBankTransactionsRequest(csv));

        var tx = response.transactions().getFirst();
        assertEquals("SUGGESTED", tx.status());
        assertEquals("ACCOUNT", tx.suggestedMatches().getFirst().matchType());
        verify(journalService, never()).postJournal(any());
    }

    @Test
    void importCsv_ruleMatch_autoApply_deletedTargetGl_fallsBackToSuggestedNotAbort() {
        BankRule r = rule("5230", true);
        UUID acctMatchId = UUID.randomUUID();
        java.util.concurrent.atomic.AtomicReference<PaymentMatch> saved = new java.util.concurrent.atomic.AtomicReference<>();
        java.util.concurrent.atomic.AtomicReference<BankTransaction> savedTx = new java.util.concurrent.atomic.AtomicReference<>();
        Account bank = Account.builder().code("1020").name("Bank").type("ASSET").build();

        when(bankRuleService.firstMatch(eq(orgId), any(BankTransaction.class))).thenReturn(Optional.of(r));
        when(bankTransactionRepository.existsByOrgIdAndUtrAndDirectionAndTransactionDateAndAmount(any(), any(), any(), any(), any())).thenReturn(false);
        when(bankTransactionRepository.save(any(BankTransaction.class))).thenAnswer(inv -> {
            BankTransaction tx = inv.getArgument(0);
            if (tx.getId() == null) tx.setId(UUID.randomUUID());
            if (tx.getCreatedAt() == null) tx.setCreatedAt(Instant.now());
            savedTx.set(tx);
            return tx;
        });
        when(paymentMatchRepository.save(any(PaymentMatch.class))).thenAnswer(inv -> {
            PaymentMatch m = inv.getArgument(0);
            if (m.getId() == null) m.setId(acctMatchId);
            saved.set(m);
            return m;
        });
        when(paymentMatchRepository.findByIdAndOrgId(eq(acctMatchId), eq(orgId)))
                .thenAnswer(inv -> Optional.of(saved.get()));
        when(bankTransactionRepository.findByIdAndOrgIdForUpdate(any(), eq(orgId)))
                .thenAnswer(inv -> Optional.ofNullable(savedTx.get()));
        when(defaultAccountService.get(orgId, DefaultAccountPurpose.BANK)).thenReturn(bank);
        when(accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, "5230"))
                .thenReturn(Optional.empty()); // target GL deleted between suggest and accept

        String csv = """
                date,amount,direction,narration,utr
                2026-05-20,150,DEBIT,MONTHLY BANK CHARGES,REF-9
                """;
        BankTransactionImportResponse response = service.importCsv(new ImportBankTransactionsRequest(csv));

        // Import survived; the un-postable auto-apply degraded to a suggestion.
        assertEquals(1, response.imported());
        assertEquals("SUGGESTED", response.transactions().getFirst().status());
        verify(journalService, never()).postJournal(any());
    }
}
