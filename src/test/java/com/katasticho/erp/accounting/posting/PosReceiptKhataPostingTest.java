package com.katasticho.erp.accounting.posting;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.inventory.service.CostResolverService;
import com.katasticho.erp.pos.entity.PaymentMode;
import com.katasticho.erp.pos.entity.SalesReceipt;
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
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Khata (CREDIT) POS receipt: the DR leg must be Accounts Receivable —
 * nothing hits the till. Revenue/tax/COGS legs are untouched by the mode.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class PosReceiptKhataPostingTest {

    @Mock private JournalService journalService;
    @Mock private com.katasticho.erp.accounting.defaults.service.DefaultAccountService defaultAccountService;
    @Mock private com.katasticho.erp.ar.repository.TaxLineItemRepository taxLineItemRepository;
    @Mock private com.katasticho.erp.accounting.repository.AccountRepository accountRepository;
    @Mock private SalesInvoicePostingRule salesInvoicePostingRule;
    @Mock private CostResolverService costResolverService;

    @InjectMocks private AccountingPostingEngine engine;

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        when(defaultAccountService.getCode(eq(orgId), eq(DefaultAccountPurpose.AR))).thenReturn("1100");
        when(defaultAccountService.getCode(eq(orgId), eq(DefaultAccountPurpose.CASH))).thenReturn("1010");
        when(defaultAccountService.getCode(eq(orgId), eq(DefaultAccountPurpose.SALES_REVENUE))).thenReturn("4010");
        when(journalService.postJournal(any())).thenReturn(new JournalEntry());
    }

    private SalesReceipt receipt(PaymentMode mode) {
        SalesReceipt r = SalesReceipt.builder()
                .receiptNumber("SR-2026-000042")
                .receiptDate(LocalDate.of(2026, 7, 2))
                .paymentMode(mode)
                .contactId(UUID.randomUUID())
                .subtotal(new BigDecimal("100.00"))
                .taxAmount(BigDecimal.ZERO)
                .total(new BigDecimal("100.00"))
                .build();
        r.setOrgId(orgId);
        return r;
    }

    @Test
    void creditReceiptDebitsAccountsReceivableNotCash() {
        engine.postPosReceipt(receipt(PaymentMode.CREDIT), List.of(), Map.of());

        ArgumentCaptor<JournalPostRequest> captor = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(captor.capture());
        var lines = captor.getValue().lines();

        assertThat(lines.get(0).accountCode()).isEqualTo("1100");
        assertThat(lines.get(0).debit()).isEqualByComparingTo("100.00");
        assertThat(lines).noneMatch(l -> "1010".equals(l.accountCode()));
        // revenue leg unchanged
        assertThat(lines.get(1).accountCode()).isEqualTo("4010");
        assertThat(lines.get(1).credit()).isEqualByComparingTo("100.00");
    }

    @Test
    void cashReceiptStillDebitsCash() {
        engine.postPosReceipt(receipt(PaymentMode.CASH), List.of(), Map.of());

        ArgumentCaptor<JournalPostRequest> captor = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(captor.capture());
        assertThat(captor.getValue().lines().get(0).accountCode()).isEqualTo("1010");
    }
}
