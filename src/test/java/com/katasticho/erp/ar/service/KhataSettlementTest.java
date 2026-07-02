package com.katasticho.erp.ar.service;

import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.posting.AccountingPostingEngine;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ar.entity.CustomerReceipt;
import com.katasticho.erp.ar.repository.CustomerReceiptRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.common.snapshot.DocumentSnapshotService;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
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
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Khata settlement: collecting against invoice-less outstanding (POS credit
 * sales). Journal = DR Cash / CR AR via one synthetic allocation; outstanding
 * decreases; over-collection and non-customers are rejected.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class KhataSettlementTest {

    @Mock private CustomerReceiptRepository receiptRepository;
    @Mock private InvoiceRepository invoiceRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private OrganisationRepository organisationRepository;
    @Mock private BranchRepository branchRepository;
    @Mock private JournalService journalService;
    @Mock private AccountingPostingEngine postingEngine;
    @Mock private InvoiceService invoiceService;
    @Mock private CurrencyService currencyService;
    @Mock private CommentService commentService;
    @Mock private DocumentSnapshotService documentSnapshotService;

    @InjectMocks private CustomerReceiptService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID contactId = UUID.randomUUID();
    private Contact customer;

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());

        customer = Contact.builder()
                .displayName("Khata Kirana Store")
                .contactType(ContactType.CUSTOMER)
                .outstandingAr(new BigDecimal("500.00"))
                .build();
        customer.setId(contactId);
        customer.setOrgId(orgId);

        Organisation org = mock(Organisation.class);
        when(org.getBaseCurrency()).thenReturn("INR");
        when(org.getFiscalYearStart()).thenReturn(4);
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(customer));
        when(contactRepository.findById(contactId)).thenReturn(Optional.of(customer));
        when(currencyService.getRate(anyString(), anyString(), any())).thenReturn(BigDecimal.ONE);
        when(invoiceService.computeFiscalYear(any(), anyInt())).thenReturn(2026);
        when(invoiceService.generateNumber(eq(orgId), eq("RCPT"), anyInt()))
                .thenReturn("RCPT-2026-000001");
        JournalEntry journalEntry = mock(JournalEntry.class);
        when(journalEntry.getId()).thenReturn(UUID.randomUUID());
        when(postingEngine.postCustomerReceipt(any(), any(), any(), any(), any(), any(), any(), any()))
                .thenReturn(journalEntry);
        when(branchRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.empty());
        when(receiptRepository.save(any(CustomerReceipt.class))).thenAnswer(inv -> {
            CustomerReceipt r = inv.getArgument(0);
            if (r.getId() == null) r.setId(UUID.randomUUID());
            return r;
        });
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void settlementPostsArCreditAndReducesOutstanding() {
        var response = service.recordKhataSettlement(
                contactId, new BigDecimal("200.00"), "CASH", LocalDate.of(2026, 7, 2), "paid at counter");

        assertThat(customer.getOutstandingAr()).isEqualByComparingTo("300.00");
        verify(contactRepository).save(customer);

        // journal: full amount allocated to AR, zero advance
        @SuppressWarnings("unchecked")
        ArgumentCaptor<List<AccountingPostingEngine.ArAllocationFx>> allocations =
                ArgumentCaptor.forClass(List.class);
        ArgumentCaptor<BigDecimal> advance = ArgumentCaptor.forClass(BigDecimal.class);
        verify(postingEngine).postCustomerReceipt(eq(orgId), eq("RCPT-2026-000001"),
                eq(LocalDate.of(2026, 7, 2)), eq(new BigDecimal("200.00")),
                advance.capture(), eq("CASH"), any(), allocations.capture());
        assertThat(advance.getValue()).isEqualByComparingTo("0");
        assertThat(allocations.getValue()).hasSize(1);
        assertThat(allocations.getValue().get(0).amount()).isEqualByComparingTo("200.00");

        assertThat(response.allocatedAmount()).isEqualByComparingTo("200.00");
        assertThat(response.notes()).contains("Khata settlement");
    }

    @Test
    void settlementBeyondOutstandingIsRejected() {
        assertThatThrownBy(() -> service.recordKhataSettlement(
                contactId, new BigDecimal("600.00"), "CASH", LocalDate.of(2026, 7, 2), null))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "AR_KHATA_EXCEEDS_OUTSTANDING");
        verify(postingEngine, never()).postCustomerReceipt(any(), any(), any(), any(), any(), any(), any(), any());
    }

    @Test
    void nonCustomerAndNonPositiveAmountsAreRejected() {
        customer.setContactType(ContactType.VENDOR);
        assertThatThrownBy(() -> service.recordKhataSettlement(
                contactId, new BigDecimal("100.00"), "CASH", LocalDate.of(2026, 7, 2), null))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "AR_CONTACT_NOT_CUSTOMER");

        assertThatThrownBy(() -> service.recordKhataSettlement(
                contactId, BigDecimal.ZERO, "CASH", LocalDate.of(2026, 7, 2), null))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "AR_KHATA_AMOUNT_INVALID");
    }
}
