package com.katasticho.erp.banking.service;

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
    @Mock private ContactRepository contactRepository;
    @Mock private PaymentService paymentService;

    private BankReconciliationService service;
    private UUID orgId;
    private UUID userId;

    @BeforeEach
    void setUp() {
        service = new BankReconciliationService(
                bankTransactionRepository,
                paymentMatchRepository,
                invoiceRepository,
                contactRepository,
                paymentService
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
}
