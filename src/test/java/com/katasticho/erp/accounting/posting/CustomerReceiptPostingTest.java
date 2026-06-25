package com.katasticho.erp.accounting.posting;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
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
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

/**
 * Customer-receipt journal (C3): a lump-sum collection split across invoices
 * with the excess parked as a Customer Advance (2100). Cash debited, AR cleared
 * for Σ allocations, advance credited for the remainder, forex (5500) balances
 * when invoice rates differ from the receipt rate. Every journal must balance.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class CustomerReceiptPostingTest {

    @Mock private JournalService journalService;
    @Mock private com.katasticho.erp.accounting.defaults.service.DefaultAccountService defaultAccountService;
    @Mock private com.katasticho.erp.ar.repository.TaxLineItemRepository taxLineItemRepository;
    @Mock private com.katasticho.erp.accounting.repository.AccountRepository accountRepository;
    @Mock private SalesInvoicePostingRule salesInvoicePostingRule;

    @InjectMocks private AccountingPostingEngine engine;

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        // Distinct codes per purpose so each journal line is identifiable.
        when(defaultAccountService.getCode(eq(orgId), eq(DefaultAccountPurpose.BANK))).thenReturn("1020");
        when(defaultAccountService.getCode(eq(orgId), eq(DefaultAccountPurpose.CASH))).thenReturn("1010");
        when(defaultAccountService.getCode(eq(orgId), eq(DefaultAccountPurpose.AR))).thenReturn("1100");
        when(defaultAccountService.getCode(eq(orgId), eq(DefaultAccountPurpose.CUSTOMER_ADVANCE))).thenReturn("2100");
        when(journalService.postJournal(any())).thenReturn(new JournalEntry());
    }

    private JournalPostRequest post(BigDecimal amount, BigDecimal advance,
                                    List<AccountingPostingEngine.ArAllocationFx> fx,
                                    BigDecimal receiptRate) {
        engine.postCustomerReceipt(orgId, "RCPT-1", LocalDate.of(2026, 6, 1),
                amount, advance, "BANK_TRANSFER", receiptRate, fx);
        ArgumentCaptor<JournalPostRequest> captor = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(captor.capture());
        return captor.getValue();
    }

    private static void assertBalanced(List<JournalLineRequest> lines) {
        BigDecimal dr = lines.stream().map(JournalLineRequest::debit).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal cr = lines.stream().map(JournalLineRequest::credit).reduce(BigDecimal.ZERO, BigDecimal::add);
        assertEquals(0, dr.compareTo(cr), "journal must balance: DR " + dr + " vs CR " + cr);
    }

    private static JournalLineRequest line(List<JournalLineRequest> lines, String code) {
        return lines.stream().filter(l -> code.equals(l.accountCode())).findFirst().orElse(null);
    }

    @Test
    void multiInvoiceWithAdvance_splitsCashIntoArAndAdvance() {
        // ₹10,000 received; ₹6,000 + ₹3,000 applied to two invoices; ₹1,000 advance.
        var fx = List.of(
                new AccountingPostingEngine.ArAllocationFx(new BigDecimal("6000"), BigDecimal.ONE),
                new AccountingPostingEngine.ArAllocationFx(new BigDecimal("3000"), BigDecimal.ONE));
        JournalPostRequest req = post(new BigDecimal("10000"), new BigDecimal("1000"), fx, BigDecimal.ONE);

        List<JournalLineRequest> lines = req.lines();
        assertEquals(3, lines.size());
        assertEquals(0, new BigDecimal("10000.00").compareTo(line(lines, "1020").debit()));  // cash
        assertEquals(0, new BigDecimal("9000.00").compareTo(line(lines, "1100").credit()));   // AR
        assertEquals(0, new BigDecimal("1000.00").compareTo(line(lines, "2100").credit()));   // advance
        assertNull(line(lines, "5500"), "no forex line when rates are 1");
        assertBalanced(lines);
    }

    @Test
    void pureAdvance_noAllocations_postsAdvanceOnly() {
        JournalPostRequest req = post(new BigDecimal("5000"), new BigDecimal("5000"), List.of(), BigDecimal.ONE);

        List<JournalLineRequest> lines = req.lines();
        assertEquals(2, lines.size());
        assertEquals(0, new BigDecimal("5000.00").compareTo(line(lines, "1020").debit()));   // cash
        assertEquals(0, new BigDecimal("5000.00").compareTo(line(lines, "2100").credit()));  // advance
        assertNull(line(lines, "1100"), "no AR line when nothing is allocated");
        assertBalanced(lines);
    }

    @Test
    void fullyAllocated_noAdvance_postsArOnly() {
        var fx = List.of(new AccountingPostingEngine.ArAllocationFx(new BigDecimal("9000"), BigDecimal.ONE));
        JournalPostRequest req = post(new BigDecimal("9000"), BigDecimal.ZERO, fx, BigDecimal.ONE);

        List<JournalLineRequest> lines = req.lines();
        assertEquals(2, lines.size());
        assertEquals(0, new BigDecimal("9000.00").compareTo(line(lines, "1020").debit()));   // cash
        assertEquals(0, new BigDecimal("9000.00").compareTo(line(lines, "1100").credit()));  // AR
        assertNull(line(lines, "2100"), "no advance line when fully allocated");
        assertBalanced(lines);
    }

    @Test
    void forexWhenInvoiceRateDiffersFromReceiptRate_balancesWithForexLine() {
        // $100 invoice booked @82, fully settled by a $100 receipt @84 -> ₹200 gain.
        var fx = List.of(new AccountingPostingEngine.ArAllocationFx(new BigDecimal("100"), new BigDecimal("82")));
        JournalPostRequest req = post(new BigDecimal("100"), BigDecimal.ZERO, fx, new BigDecimal("84"));

        List<JournalLineRequest> lines = req.lines();
        assertEquals(3, lines.size());
        assertEquals(0, new BigDecimal("8400.00").compareTo(line(lines, "1020").debit()));   // cash @84
        assertEquals(0, new BigDecimal("8200.00").compareTo(line(lines, "1100").credit()));  // AR @82
        JournalLineRequest forex = line(lines, "5500");
        assertNotNull(forex);
        assertEquals(0, new BigDecimal("200.00").compareTo(forex.credit()));                 // realized gain
        assertBalanced(lines);
    }
}
