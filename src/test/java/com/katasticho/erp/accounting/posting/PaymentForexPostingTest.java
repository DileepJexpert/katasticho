package com.katasticho.erp.accounting.posting;

import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.service.JournalService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * Realized forex gain/loss on payment receipt: AR clears at the invoice
 * rate, cash books at the payment-date rate, difference goes to 5500.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class PaymentForexPostingTest {

    @Mock private JournalService journalService;
    @Mock private com.katasticho.erp.accounting.defaults.service.DefaultAccountService defaultAccountService;
    @Mock private com.katasticho.erp.ar.repository.TaxLineItemRepository taxLineItemRepository;
    @Mock private com.katasticho.erp.accounting.repository.AccountRepository accountRepository;
    @Mock private SalesInvoicePostingRule salesInvoicePostingRule;

    @InjectMocks private AccountingPostingEngine engine;

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        when(defaultAccountService.getCode(eq(orgId), any())).thenReturn("1100");
        JournalEntry entry = new JournalEntry();
        when(journalService.postJournal(any())).thenReturn(entry);
    }

    private JournalPostRequest post(BigDecimal amount, BigDecimal invRate, BigDecimal payRate) {
        engine.postPaymentReceived(orgId, "PAY-1", "INV-1",
                LocalDate.of(2026, 6, 1), amount, "BANK_TRANSFER", invRate, payRate);
        ArgumentCaptor<JournalPostRequest> captor = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(captor.capture());
        return captor.getValue();
    }

    @Test
    void sameRate_postsLegacyTwoLineJournal() {
        JournalPostRequest req = post(new BigDecimal("5000"), BigDecimal.ONE, BigDecimal.ONE);

        List<JournalLineRequest> lines = req.lines();
        assertEquals(2, lines.size());
        assertEquals(0, new BigDecimal("5000.00").compareTo(lines.get(0).debit()));
        assertEquals(0, new BigDecimal("5000.00").compareTo(lines.get(1).credit()));
    }

    @Test
    void paymentRateHigher_postsForexGainCredit() {
        // $100 invoice booked @82, settled @84 -> gain 200
        JournalPostRequest req = post(new BigDecimal("100"),
                new BigDecimal("82"), new BigDecimal("84"));

        List<JournalLineRequest> lines = req.lines();
        assertEquals(3, lines.size());
        assertEquals(0, new BigDecimal("8400.00").compareTo(lines.get(0).debit()));   // bank
        assertEquals(0, new BigDecimal("8200.00").compareTo(lines.get(1).credit()));  // AR
        JournalLineRequest forex = lines.get(2);
        assertEquals("5500", forex.accountCode());
        assertEquals(0, new BigDecimal("200.00").compareTo(forex.credit()));          // gain
        assertEquals(0, BigDecimal.ZERO.compareTo(forex.debit()));

        BigDecimal totalDebit = lines.stream().map(JournalLineRequest::debit)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal totalCredit = lines.stream().map(JournalLineRequest::credit)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        assertEquals(0, totalDebit.compareTo(totalCredit));
    }

    @Test
    void paymentRateLower_postsForexLossDebit() {
        // $100 invoice booked @84, settled @81 -> loss 300
        JournalPostRequest req = post(new BigDecimal("100"),
                new BigDecimal("84"), new BigDecimal("81"));

        List<JournalLineRequest> lines = req.lines();
        assertEquals(3, lines.size());
        JournalLineRequest forex = lines.get(2);
        assertEquals("5500", forex.accountCode());
        assertEquals(0, new BigDecimal("300.00").compareTo(forex.debit()));           // loss

        BigDecimal totalDebit = lines.stream().map(JournalLineRequest::debit)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal totalCredit = lines.stream().map(JournalLineRequest::credit)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        assertEquals(0, totalDebit.compareTo(totalCredit));
    }

    @Test
    void nullRates_treatedAsOne() {
        JournalPostRequest req = post(new BigDecimal("750"), null, null);
        assertEquals(2, req.lines().size());
    }
}
