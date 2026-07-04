package com.katasticho.erp.accounting.forex.service;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.forex.dto.ForexRevaluationDtos.RevaluationResult;
import com.katasticho.erp.accounting.forex.entity.ForexRevaluationRun;
import com.katasticho.erp.accounting.forex.repository.ForexRevaluationRunRepository;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.currency.service.CurrencyManagementService;
import com.katasticho.erp.common.exception.BusinessException;
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
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ForexRevaluationServiceTest {

    @Mock private InvoiceRepository invoiceRepository;
    @Mock private PurchaseBillRepository purchaseBillRepository;
    @Mock private OrganisationRepository organisationRepository;
    @Mock private CurrencyManagementService currencyService;
    @Mock private DefaultAccountService defaultAccountService;
    @Mock private JournalService journalService;
    @Mock private ForexRevaluationRunRepository runRepository;

    private ForexRevaluationService service;
    private UUID orgId;
    private final LocalDate asOf = LocalDate.of(2026, 3, 31);

    @BeforeEach
    void setUp() {
        service = new ForexRevaluationService(invoiceRepository, purchaseBillRepository,
                organisationRepository, currencyService, defaultAccountService,
                journalService, runRepository);
        orgId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    private void stubOrg(String base) {
        when(organisationRepository.findById(orgId))
                .thenReturn(Optional.of(Organisation.builder().baseCurrency(base).build()));
    }

    private void stubAccounts() {
        when(defaultAccountService.get(orgId, DefaultAccountPurpose.AR)).thenReturn(acct("1100"));
        when(defaultAccountService.get(orgId, DefaultAccountPurpose.AP)).thenReturn(acct("2010"));
    }

    private Account acct(String code) {
        return Account.builder().code(code).name(code).type("X").build();
    }

    private void stubNoExistingRun() {
        when(runRepository.findByOrgIdAndAsOfDate(orgId, asOf)).thenReturn(Optional.empty());
    }

    private void stubRunSave() {
        when(runRepository.save(any(ForexRevaluationRun.class))).thenAnswer(inv -> {
            ForexRevaluationRun r = inv.getArgument(0);
            if (r.getId() == null) r.setId(UUID.randomUUID());
            return r;
        });
    }

    private void stubTwoJournals() {
        JournalEntry reval = mock(JournalEntry.class);
        JournalEntry reversal = mock(JournalEntry.class);
        when(reval.getId()).thenReturn(UUID.randomUUID());
        when(reversal.getId()).thenReturn(UUID.randomUUID());
        when(journalService.postJournal(any(JournalPostRequest.class))).thenReturn(reval, reversal);
    }

    private Invoice inv(String currency, String balance, String rate, LocalDate date) {
        Invoice i = Invoice.builder().orgId(orgId).invoiceNumber("INV-" + currency)
                .currency(currency).balanceDue(new BigDecimal(balance))
                .exchangeRate(new BigDecimal(rate)).invoiceDate(date).status("SENT").build();
        i.setId(UUID.randomUUID());
        return i;
    }

    private PurchaseBill bill(String currency, String balance, String rate, LocalDate date) {
        return PurchaseBill.builder().orgId(orgId).billNumber("BILL-" + currency)
                .contactId(UUID.randomUUID())
                .currency(currency).balanceDue(new BigDecimal(balance))
                .exchangeRate(new BigDecimal(rate)).billDate(date).status("OPEN")
                .id(UUID.randomUUID()).build();
    }

    private JournalLineRequest lineFor(JournalPostRequest r, String code) {
        return r.lines().stream().filter(l -> l.accountCode().equals(code)).findFirst()
                .orElseThrow(() -> new AssertionError("no line for " + code + " in " + r.lines()));
    }

    private boolean hasLine(JournalPostRequest r, String code) {
        return r.lines().stream().anyMatch(l -> l.accountCode().equals(code));
    }

    private List<JournalPostRequest> captureJournals(int times) {
        ArgumentCaptor<JournalPostRequest> cap = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService, times(times)).postJournal(cap.capture());
        return cap.getAllValues();
    }

    // ── Tests ─────────────────────────────────────────────────────────────────

    @Test
    void arAppreciated_postsDrArCrForexGain_andReverses() {
        stubOrg("INR"); stubAccounts(); stubNoExistingRun(); stubRunSave(); stubTwoJournals();
        when(invoiceRepository.findOutstandingInvoices(orgId))
                .thenReturn(List.of(inv("USD", "1000", "80", LocalDate.of(2026, 1, 10))));
        when(purchaseBillRepository.findOutstandingBills(orgId)).thenReturn(List.of());
        when(currencyService.getExchangeRate("USD", "INR", asOf)).thenReturn(new BigDecimal("83"));

        var resp = service.revalue(asOf);
        assertEquals(0, resp.arDelta().compareTo(new BigDecimal("3000.00")));
        assertEquals(0, resp.netGainLoss().compareTo(new BigDecimal("3000.00")));
        assertEquals(1, resp.revaluedDocumentCount());

        List<JournalPostRequest> js = captureJournals(2);
        JournalPostRequest reval = js.get(0);
        assertEquals(asOf, reval.effectiveDate());
        assertEquals("FOREX_REVAL", reval.sourceModule());
        assertEquals(0, lineFor(reval, "1100").debit().compareTo(new BigDecimal("3000.00")));   // DR AR
        assertEquals(0, lineFor(reval, "1100").credit().signum());
        assertEquals(0, lineFor(reval, "5500").credit().compareTo(new BigDecimal("3000.00")));  // CR forex gain
        assertFalse(hasLine(reval, "2010"));                                                     // no AP line

        JournalPostRequest reversal = js.get(1);
        assertEquals(asOf.plusDays(1), reversal.effectiveDate());
        assertEquals(0, lineFor(reversal, "1100").credit().compareTo(new BigDecimal("3000.00"))); // CR AR (reversed)
        assertEquals(0, lineFor(reversal, "5500").debit().compareTo(new BigDecimal("3000.00")));  // DR forex (reversed)
    }

    @Test
    void arDepreciated_postsCrArDrForexLoss() {
        stubOrg("INR"); stubAccounts(); stubNoExistingRun(); stubRunSave(); stubTwoJournals();
        when(invoiceRepository.findOutstandingInvoices(orgId))
                .thenReturn(List.of(inv("USD", "1000", "80", LocalDate.of(2026, 1, 10))));
        when(purchaseBillRepository.findOutstandingBills(orgId)).thenReturn(List.of());
        when(currencyService.getExchangeRate("USD", "INR", asOf)).thenReturn(new BigDecimal("78"));

        var resp = service.revalue(asOf);
        assertEquals(0, resp.arDelta().compareTo(new BigDecimal("-2000.00")));

        JournalPostRequest reval = captureJournals(2).get(0);
        assertEquals(0, lineFor(reval, "1100").credit().compareTo(new BigDecimal("2000.00")));  // CR AR
        assertEquals(0, lineFor(reval, "5500").debit().compareTo(new BigDecimal("2000.00")));   // DR forex loss
    }

    @Test
    void apAppreciated_postsCrApDrForexLoss() {
        stubOrg("INR"); stubAccounts(); stubNoExistingRun(); stubRunSave(); stubTwoJournals();
        when(invoiceRepository.findOutstandingInvoices(orgId)).thenReturn(List.of());
        when(purchaseBillRepository.findOutstandingBills(orgId))
                .thenReturn(List.of(bill("EUR", "500", "90", LocalDate.of(2026, 2, 1))));
        when(currencyService.getExchangeRate("EUR", "INR", asOf)).thenReturn(new BigDecimal("95"));

        var resp = service.revalue(asOf);
        assertEquals(0, resp.apDelta().compareTo(new BigDecimal("2500.00")));
        assertEquals(0, resp.netGainLoss().compareTo(new BigDecimal("-2500.00"))); // net loss

        JournalPostRequest reval = captureJournals(2).get(0);
        assertEquals(0, lineFor(reval, "2010").credit().compareTo(new BigDecimal("2500.00"))); // CR AP (liability up)
        assertEquals(0, lineFor(reval, "5500").debit().compareTo(new BigDecimal("2500.00")));  // DR forex loss
        assertFalse(hasLine(reval, "1100"));
    }

    @Test
    void arGainAndApLoss_consolidatedBalances() {
        stubOrg("INR"); stubAccounts(); stubNoExistingRun(); stubRunSave(); stubTwoJournals();
        when(invoiceRepository.findOutstandingInvoices(orgId))
                .thenReturn(List.of(inv("USD", "1000", "80", LocalDate.of(2026, 1, 10)))); // +3000 gain
        when(purchaseBillRepository.findOutstandingBills(orgId))
                .thenReturn(List.of(bill("EUR", "200", "90", LocalDate.of(2026, 2, 1))));  // +1000 (AP up = loss)
        when(currencyService.getExchangeRate("USD", "INR", asOf)).thenReturn(new BigDecimal("83"));
        when(currencyService.getExchangeRate("EUR", "INR", asOf)).thenReturn(new BigDecimal("95"));

        var resp = service.revalue(asOf);
        assertEquals(0, resp.arDelta().compareTo(new BigDecimal("3000.00")));
        assertEquals(0, resp.apDelta().compareTo(new BigDecimal("1000.00")));
        assertEquals(0, resp.netGainLoss().compareTo(new BigDecimal("2000.00"))); // net gain

        JournalPostRequest reval = captureJournals(2).get(0);
        // DR AR 3000 = CR AP 1000 + CR forex 2000
        assertEquals(0, lineFor(reval, "1100").debit().compareTo(new BigDecimal("3000.00")));
        assertEquals(0, lineFor(reval, "2010").credit().compareTo(new BigDecimal("1000.00")));
        assertEquals(0, lineFor(reval, "5500").credit().compareTo(new BigDecimal("2000.00")));
        BigDecimal dr = reval.lines().stream().map(JournalLineRequest::debit).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal cr = reval.lines().stream().map(JournalLineRequest::credit).reduce(BigDecimal.ZERO, BigDecimal::add);
        assertEquals(0, dr.compareTo(cr)); // journal balances
    }

    @Test
    void baseCurrencyInvoice_isSkipped() {
        stubOrg("INR"); stubNoExistingRun();
        when(invoiceRepository.findOutstandingInvoices(orgId))
                .thenReturn(List.of(inv("INR", "1000", "1", LocalDate.of(2026, 1, 10))));
        when(purchaseBillRepository.findOutstandingBills(orgId)).thenReturn(List.of());

        var resp = service.revalue(asOf);
        assertEquals(0, resp.arDelta().signum());
        assertEquals(0, resp.revaluedDocumentCount());
        verify(currencyService, never()).getExchangeRate(any(), any(), any());
        verify(journalService, never()).postJournal(any()); // nothing to post
        verify(runRepository, never()).save(any());          // zero-delta doesn't lock the date
    }

    @Test
    void noClosingRate_skipsWithWarning() {
        stubOrg("INR");
        when(invoiceRepository.findOutstandingInvoices(orgId))
                .thenReturn(List.of(inv("USD", "1000", "80", LocalDate.of(2026, 1, 10))));
        when(purchaseBillRepository.findOutstandingBills(orgId)).thenReturn(List.of());
        when(currencyService.getExchangeRate("USD", "INR", asOf))
                .thenThrow(new BusinessException("no rate", "CURRENCY_NO_RATE"));

        RevaluationResult result = service.preview(asOf);
        assertEquals(0, result.arDelta().signum());
        assertEquals(0, result.revaluedDocumentCount());
        assertEquals(1, result.warnings().size());
    }

    @Test
    void zeroDelta_postsNoJournal_andDoesNotLockTheDate() {
        stubOrg("INR"); stubNoExistingRun();
        when(invoiceRepository.findOutstandingInvoices(orgId))
                .thenReturn(List.of(inv("USD", "1000", "80", LocalDate.of(2026, 1, 10))));
        when(purchaseBillRepository.findOutstandingBills(orgId)).thenReturn(List.of());
        when(currencyService.getExchangeRate("USD", "INR", asOf)).thenReturn(new BigDecimal("80")); // unchanged

        var resp = service.revalue(asOf);
        assertEquals(0, resp.arDelta().signum());
        assertNull(resp.id());                                       // no run row (date not locked)
        verify(runRepository, never()).save(any(ForexRevaluationRun.class)); // nothing recorded
        verify(journalService, never()).postJournal(any());          // nothing posted
    }

    @Test
    void alreadyRunForDate_throws() {
        when(runRepository.findByOrgIdAndAsOfDate(orgId, asOf))
                .thenReturn(Optional.of(ForexRevaluationRun.builder().asOfDate(asOf).build()));

        var ex = assertThrows(BusinessException.class, () -> service.revalue(asOf));
        assertEquals("FOREX_REVAL_ALREADY_RUN", ex.getErrorCode());
        verify(journalService, never()).postJournal(any());
        verify(runRepository, never()).save(any());
    }

    @Test
    void preview_doesNotPostOrRecord() {
        stubOrg("INR");
        when(invoiceRepository.findOutstandingInvoices(orgId))
                .thenReturn(List.of(inv("USD", "1000", "80", LocalDate.of(2026, 1, 10))));
        when(purchaseBillRepository.findOutstandingBills(orgId)).thenReturn(List.of());
        when(currencyService.getExchangeRate("USD", "INR", asOf)).thenReturn(new BigDecimal("83"));

        RevaluationResult result = service.preview(asOf);
        assertEquals(0, result.arDelta().compareTo(new BigDecimal("3000.00")));
        assertEquals(1, result.lines().size());
        verify(journalService, never()).postJournal(any());
        verify(runRepository, never()).save(any());
    }
}
