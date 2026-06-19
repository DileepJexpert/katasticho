package com.katasticho.erp.accounting.service;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.OrgSettingsService;
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
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class InterestChargeServiceTest {

    @Mock private InvoiceRepository invoiceRepository;
    @Mock private JournalService journalService;
    @Mock private DefaultAccountService defaultAccountService;
    @Mock private OrgSettingsService orgSettingsService;
    private InterestChargeService service;

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new InterestChargeService(
                invoiceRepository, journalService, defaultAccountService, orgSettingsService);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
    }

    @AfterEach
    void tearDown() { TenantContext.clear(); }

    private Invoice invoice(UUID id, LocalDate due, BigDecimal balance) {
        return Invoice.builder()
                .id(id)
                .orgId(orgId)
                .invoiceNumber("INV-001")
                .dueDate(due)
                .balanceDue(balance)
                .build();
    }

    private JournalEntry entry() {
        return JournalEntry.builder()
                .id(UUID.randomUUID())
                .entryNumber("JE-2026-00001")
                .build();
    }

    @Test
    void drafts_balancedJournal_DRAR_CRInterestIncome_atConfiguredRate() {
        UUID invId = UUID.randomUUID();
        // 100 days overdue at 18% p.a. on ₹100,000 = 100000 × 18 × 100 / 36500 = ₹4,931.51
        Invoice inv = invoice(invId, LocalDate.now().minusDays(100), new BigDecimal("100000.00"));
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invId, orgId)).thenReturn(Optional.of(inv));
        when(orgSettingsService.get(eq(orgId), eq("ar.interest_rate_pa"), any())).thenReturn("18");
        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.AR)).thenReturn("1100");
        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.INTEREST_INCOME)).thenReturn("4110");
        when(journalService.postJournal(any(JournalPostRequest.class))).thenReturn(entry());

        InterestChargeService.InterestDraftResult result = service.draftInterestDebitNote(invId);

        ArgumentCaptor<JournalPostRequest> cap = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(cap.capture());
        JournalPostRequest posted = cap.getValue();

        assertFalse(posted.autoPost(), "Interest draft must stay DRAFT for review");
        assertEquals("INTEREST_CHARGE", posted.sourceModule());
        assertEquals(invId, posted.sourceId());
        assertEquals(2, posted.lines().size());

        JournalLineRequest dr = posted.lines().get(0);
        JournalLineRequest cr = posted.lines().get(1);
        assertEquals("1100", dr.accountCode());
        assertEquals("4110", cr.accountCode());
        assertEquals(0, dr.debit().compareTo(new BigDecimal("4931.51")));
        assertEquals(0, dr.credit().compareTo(BigDecimal.ZERO));
        assertEquals(0, cr.credit().compareTo(new BigDecimal("4931.51")));
        assertEquals(0, cr.debit().compareTo(BigDecimal.ZERO));

        assertEquals(0, result.interest().compareTo(new BigDecimal("4931.51")));
        assertEquals(100, result.daysOverdue());
        assertEquals("JE-2026-00001", result.journalEntryNumber());
    }

    @Test
    void honoursOrgSetting_forRatePerAnnum_andRecordsInDescription() {
        UUID invId = UUID.randomUUID();
        Invoice inv = invoice(invId, LocalDate.now().minusDays(30), new BigDecimal("50000.00"));
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invId, orgId)).thenReturn(Optional.of(inv));
        when(orgSettingsService.get(eq(orgId), eq("ar.interest_rate_pa"), any())).thenReturn("24");
        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.AR)).thenReturn("1100");
        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.INTEREST_INCOME)).thenReturn("4110");
        when(journalService.postJournal(any(JournalPostRequest.class))).thenReturn(entry());

        InterestChargeService.InterestDraftResult result = service.draftInterestDebitNote(invId);

        // 50000 × 24 × 30 / 36500 = 986.30 (HALF_UP)
        ArgumentCaptor<JournalPostRequest> cap = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(cap.capture());
        assertTrue(cap.getValue().description().contains("24"),
                "Description must include the rate used");
        assertEquals(0, result.interest().compareTo(new BigDecimal("986.30")));
        assertEquals(0, result.ratePerAnnum().compareTo(new BigDecimal("24")));
    }

    @Test
    void rejects_invoice_notOverdue() {
        UUID invId = UUID.randomUUID();
        Invoice inv = invoice(invId, LocalDate.now().plusDays(5), new BigDecimal("10000"));
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invId, orgId)).thenReturn(Optional.of(inv));

        BusinessException ex = assertThrows(BusinessException.class, () -> service.draftInterestDebitNote(invId));
        assertEquals("INTEREST_NOT_OVERDUE", ex.getErrorCode());
        verify(journalService, org.mockito.Mockito.never()).postJournal(any());
    }

    @Test
    void rejects_invoice_withZeroBalance() {
        UUID invId = UUID.randomUUID();
        Invoice inv = invoice(invId, LocalDate.now().minusDays(10), BigDecimal.ZERO);
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invId, orgId)).thenReturn(Optional.of(inv));

        BusinessException ex = assertThrows(BusinessException.class, () -> service.draftInterestDebitNote(invId));
        assertEquals("INTEREST_NO_BALANCE", ex.getErrorCode());
    }

    @Test
    void rejects_invoice_withoutDueDate() {
        UUID invId = UUID.randomUUID();
        Invoice inv = invoice(invId, null, new BigDecimal("1000"));
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invId, orgId)).thenReturn(Optional.of(inv));

        BusinessException ex = assertThrows(BusinessException.class, () -> service.draftInterestDebitNote(invId));
        assertEquals("INTEREST_NO_DUE_DATE", ex.getErrorCode());
    }

    @Test
    void rejects_unknownInvoice() {
        UUID invId = UUID.randomUUID();
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invId, orgId)).thenReturn(Optional.empty());

        assertThrows(BusinessException.class, () -> service.draftInterestDebitNote(invId));
    }
}
