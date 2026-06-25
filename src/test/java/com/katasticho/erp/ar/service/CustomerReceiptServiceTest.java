package com.katasticho.erp.ar.service;

import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.posting.AccountingPostingEngine;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ar.dto.CustomerReceiptRequest;
import com.katasticho.erp.ar.dto.CustomerReceiptResponse;
import com.katasticho.erp.ar.entity.CustomerReceipt;
import com.katasticho.erp.ar.entity.CustomerReceiptAllocation;
import com.katasticho.erp.ar.entity.Invoice;
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
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Multi-invoice customer receipt + advance (C3). Verifies the allocation/advance
 * math the service hands to the posting engine, the per-invoice balance updates,
 * contact-AR reduction (applied amount only — advance is a liability), and void.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class CustomerReceiptServiceTest {

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

    private CustomerReceiptService service;
    private UUID orgId;
    private UUID userId;
    private Organisation org;
    private Contact customer;
    private Map<UUID, CustomerReceipt> saved;

    private static final LocalDate DATE = LocalDate.of(2026, 6, 1);

    @BeforeEach
    void setUp() {
        service = new CustomerReceiptService(
                receiptRepository, invoiceRepository, contactRepository,
                organisationRepository, branchRepository, journalService, postingEngine,
                invoiceService, currencyService, commentService, documentSnapshotService);

        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);

        org = Organisation.builder().name("Test Corp").build();
        org.setId(orgId);

        customer = Contact.builder()
                .contactType(ContactType.CUSTOMER)
                .displayName("Acme Traders")
                .outstandingAr(new BigDecimal("100000"))
                .build();
        customer.setId(UUID.randomUUID());

        lenient().when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        lenient().when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(customer.getId(), orgId))
                .thenReturn(Optional.of(customer));
        lenient().when(contactRepository.findById(customer.getId())).thenReturn(Optional.of(customer));
        lenient().when(currencyService.getRate(any(), any(), any())).thenReturn(BigDecimal.ONE);
        lenient().when(invoiceService.computeFiscalYear(any(LocalDate.class), anyInt())).thenReturn(2026);
        lenient().when(invoiceService.generateNumber(eq(orgId), eq("RCPT"), anyInt()))
                .thenReturn("RCPT-2026-000001");
        lenient().when(branchRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.empty());

        JournalEntry journal = JournalEntry.builder().entryNumber("JE-1").status("POSTED").build();
        journal.setId(UUID.randomUUID());
        lenient().when(postingEngine.postCustomerReceipt(any(), any(), any(), any(), any(), any(), any(), anyList()))
                .thenReturn(journal);

        saved = new HashMap<>();
        lenient().when(receiptRepository.save(any(CustomerReceipt.class))).thenAnswer(inv -> {
            CustomerReceipt r = inv.getArgument(0);
            if (r.getId() == null) r.setId(UUID.randomUUID());
            saved.put(r.getId(), r);
            return r;
        });
        lenient().when(receiptRepository.findByIdAndOrgIdAndIsDeletedFalse(any(UUID.class), eq(orgId)))
                .thenAnswer(inv -> Optional.ofNullable(saved.get(inv.getArgument(0))));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private Invoice invoice(String number, String balance) {
        Invoice inv = Invoice.builder()
                .orgId(orgId).contactId(customer.getId())
                .invoiceNumber(number).status("SENT")
                .totalAmount(new BigDecimal(balance))
                .amountPaid(BigDecimal.ZERO)
                .balanceDue(new BigDecimal(balance))
                .exchangeRate(BigDecimal.ONE)
                .build();
        inv.setId(UUID.randomUUID());
        lenient().when(invoiceRepository.findLockedByIdAndOrgIdAndIsDeletedFalse(inv.getId(), orgId))
                .thenReturn(Optional.of(inv));
        lenient().when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(inv.getId(), orgId))
                .thenReturn(Optional.of(inv));
        lenient().when(invoiceRepository.findById(inv.getId())).thenReturn(Optional.of(inv));
        return inv;
    }

    private CustomerReceiptRequest.AllocationRequest alloc(Invoice inv, String amt) {
        return new CustomerReceiptRequest.AllocationRequest(inv.getId(), new BigDecimal(amt));
    }

    @Test
    void allocatesAcrossInvoices_reducesEachBalanceAndContactAr() {
        Invoice inv1 = invoice("INV-1", "6000");
        Invoice inv2 = invoice("INV-2", "4000");

        var req = new CustomerReceiptRequest(customer.getId(), new BigDecimal("9000"),
                "BANK_TRANSFER", DATE, "UTR1", "two invoices", null,
                List.of(alloc(inv1, "6000"), alloc(inv2, "3000")));

        CustomerReceiptResponse resp = service.recordReceipt(req);

        // each invoice settled by its share
        verify(invoiceService).updatePaymentStatus(inv1, new BigDecimal("6000"));
        verify(invoiceService).updatePaymentStatus(inv2, new BigDecimal("3000"));

        // posting engine got amount=9000, advance=0, two fx rows
        ArgumentCaptor<BigDecimal> amt = ArgumentCaptor.forClass(BigDecimal.class);
        ArgumentCaptor<BigDecimal> adv = ArgumentCaptor.forClass(BigDecimal.class);
        ArgumentCaptor<List> fx = ArgumentCaptor.forClass(List.class);
        verify(postingEngine).postCustomerReceipt(eq(orgId), anyString(), any(),
                amt.capture(), adv.capture(), eq("BANK_TRANSFER"), any(), fx.capture());
        assertEquals(0, new BigDecimal("9000").compareTo(amt.getValue()));
        assertEquals(0, BigDecimal.ZERO.compareTo(adv.getValue()));
        assertEquals(2, fx.getValue().size());

        // applied amount (9000) leaves the receivable; advance is 0 here
        assertEquals(0, new BigDecimal("91000").compareTo(customer.getOutstandingAr()));
        assertEquals(0, new BigDecimal("9000").compareTo(resp.allocatedAmount()));
        assertEquals(0, BigDecimal.ZERO.compareTo(resp.advanceAmount()));
        assertEquals(2, resp.allocations().size());
    }

    @Test
    void overpayment_parksRemainderAsAdvance_andOnlyAppliedReducesAr() {
        Invoice inv = invoice("INV-1", "5000");

        var req = new CustomerReceiptRequest(customer.getId(), new BigDecimal("8000"),
                "CASH", DATE, null, null, null, List.of(alloc(inv, "5000")));

        CustomerReceiptResponse resp = service.recordReceipt(req);

        ArgumentCaptor<BigDecimal> adv = ArgumentCaptor.forClass(BigDecimal.class);
        verify(postingEngine).postCustomerReceipt(eq(orgId), anyString(), any(),
                any(), adv.capture(), eq("CASH"), any(), anyList());
        assertEquals(0, new BigDecimal("3000").compareTo(adv.getValue()), "advance = 8000 - 5000");

        assertEquals(0, new BigDecimal("3000").compareTo(resp.advanceAmount()));
        assertEquals(0, new BigDecimal("5000").compareTo(resp.allocatedAmount()));
        // only the applied 5000 reduces AR, not the full 8000
        assertEquals(0, new BigDecimal("95000").compareTo(customer.getOutstandingAr()));
    }

    @Test
    void pureAdvance_noAllocations_doesNotTouchInvoicesOrAr() {
        var req = new CustomerReceiptRequest(customer.getId(), new BigDecimal("2000"),
                "UPI", DATE, null, null, null, List.of());

        CustomerReceiptResponse resp = service.recordReceipt(req);

        verify(invoiceService, never()).updatePaymentStatus(any(), any());
        assertEquals(0, new BigDecimal("2000").compareTo(resp.advanceAmount()));
        assertEquals(0, BigDecimal.ZERO.compareTo(resp.allocatedAmount()));
        // AR untouched (no allocation)
        assertEquals(0, new BigDecimal("100000").compareTo(customer.getOutstandingAr()));
    }

    @Test
    void overAllocated_throws_andPostsNoJournal() {
        Invoice inv = invoice("INV-1", "6000");
        var req = new CustomerReceiptRequest(customer.getId(), new BigDecimal("5000"),
                "CASH", DATE, null, null, null, List.of(alloc(inv, "6000")));

        BusinessException ex = assertThrows(BusinessException.class, () -> service.recordReceipt(req));
        assertEquals("AR_RECEIPT_OVER_ALLOCATED", ex.getErrorCode());
        verify(postingEngine, never()).postCustomerReceipt(any(), any(), any(), any(), any(), any(), any(), anyList());
    }

    @Test
    void duplicateInvoiceAllocation_throws() {
        Invoice inv = invoice("INV-1", "9000");
        var req = new CustomerReceiptRequest(customer.getId(), new BigDecimal("5000"),
                "CASH", DATE, null, null, null, List.of(alloc(inv, "3000"), alloc(inv, "2000")));

        BusinessException ex = assertThrows(BusinessException.class, () -> service.recordReceipt(req));
        assertEquals("AR_RECEIPT_DUPLICATE_INVOICE", ex.getErrorCode());
    }

    @Test
    void allocationExceedingInvoiceBalance_throws() {
        Invoice inv = invoice("INV-1", "3000");
        var req = new CustomerReceiptRequest(customer.getId(), new BigDecimal("4000"),
                "CASH", DATE, null, null, null, List.of(alloc(inv, "4000")));

        BusinessException ex = assertThrows(BusinessException.class, () -> service.recordReceipt(req));
        assertEquals("AR_RECEIPT_ALLOCATION_EXCEEDS_BALANCE", ex.getErrorCode());
    }

    @Test
    void nonCustomerContact_throws() {
        customer.setContactType(ContactType.VENDOR);
        var req = new CustomerReceiptRequest(customer.getId(), new BigDecimal("1000"),
                "CASH", DATE, null, null, null, List.of());

        BusinessException ex = assertThrows(BusinessException.class, () -> service.recordReceipt(req));
        assertEquals("AR_CONTACT_NOT_CUSTOMER", ex.getErrorCode());
    }

    @Test
    void invoiceNotPayable_throws() {
        Invoice inv = invoice("INV-1", "5000");
        inv.setStatus("DRAFT");
        var req = new CustomerReceiptRequest(customer.getId(), new BigDecimal("3000"),
                "CASH", DATE, null, null, null, List.of(alloc(inv, "3000")));

        BusinessException ex = assertThrows(BusinessException.class, () -> service.recordReceipt(req));
        assertEquals("AR_INVOICE_NOT_PAYABLE", ex.getErrorCode());
    }

    @Test
    void voidReceipt_reversesJournal_restoresBalancesAndAr() {
        UUID invoiceId = UUID.randomUUID();
        Invoice inv = Invoice.builder()
                .orgId(orgId).contactId(customer.getId())
                .invoiceNumber("INV-1").status("PAID")
                .totalAmount(new BigDecimal("6000")).amountPaid(new BigDecimal("6000"))
                .balanceDue(BigDecimal.ZERO).exchangeRate(BigDecimal.ONE).build();
        inv.setId(invoiceId);
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId)).thenReturn(Optional.of(inv));

        UUID journalId = UUID.randomUUID();
        CustomerReceipt receipt = CustomerReceipt.builder()
                .orgId(orgId).contactId(customer.getId())
                .receiptNumber("RCPT-2026-000001").receiptDate(DATE)
                .amount(new BigDecimal("6000")).allocatedAmount(new BigDecimal("6000"))
                .advanceAmount(BigDecimal.ZERO).baseAmount(new BigDecimal("6000"))
                .paymentMethod("CASH").journalEntryId(journalId).build();
        receipt.setId(UUID.randomUUID());
        receipt.addAllocation(CustomerReceiptAllocation.builder()
                .invoiceId(invoiceId).amountApplied(new BigDecimal("6000")).build());
        saved.put(receipt.getId(), receipt);

        customer.setOutstandingAr(new BigDecimal("0"));

        CustomerReceiptResponse resp = service.voidReceipt(receipt.getId(), "customer bounced");

        verify(journalService).reverseEntry(journalId);
        verify(invoiceService).updatePaymentStatus(inv, new BigDecimal("6000").negate());
        // AR restored by the applied amount
        assertEquals(0, new BigDecimal("6000").compareTo(customer.getOutstandingAr()));
        assertTrue(saved.get(receipt.getId()).isDeleted());
        assertNotNull(resp);
    }

    @Test
    void availableAdvance_returnsRepoSum() {
        when(receiptRepository.sumAdvanceByContact(orgId, customer.getId()))
                .thenReturn(new BigDecimal("1500"));
        assertEquals(0, new BigDecimal("1500").compareTo(service.availableAdvance(customer.getId())));
    }
}
