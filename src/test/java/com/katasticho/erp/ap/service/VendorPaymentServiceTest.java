package com.katasticho.erp.ap.service;

import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.posting.AccountingPostingEngine;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ap.dto.VendorPaymentRequest;
import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.entity.VendorPayment;
import com.katasticho.erp.ap.entity.VendorPaymentAllocation;
import com.katasticho.erp.ap.match.ThreeWayMatchService;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ap.repository.VendorPaymentRepository;
import com.katasticho.erp.accounting.repository.AccountRepository;
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
import com.katasticho.erp.ar.repository.InvoiceNumberSequenceRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class VendorPaymentServiceTest {

    @Mock private VendorPaymentRepository paymentRepository;
    @Mock private PurchaseBillRepository billRepository;
    @Mock private AccountRepository accountRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private OrganisationRepository organisationRepository;
    @Mock private BranchRepository branchRepository;
    @Mock private InvoiceNumberSequenceRepository sequenceRepository;
    @Mock private JournalService journalService;
    @Mock private AccountingPostingEngine postingEngine;
    @Mock private PurchaseBillService billService;
    @Mock private ThreeWayMatchService threeWayMatchService;
    @Mock private CurrencyService currencyService;
    @Mock private CommentService commentService;
    @Mock private DocumentSnapshotService documentSnapshotService;

    private VendorPaymentService service;
    private UUID orgId;
    private Organisation org;
    private Contact vendorA;

    @BeforeEach
    void setUp() {
        service = new VendorPaymentService(
                paymentRepository, billRepository, accountRepository, contactRepository,
                organisationRepository, branchRepository, sequenceRepository, journalService,
                postingEngine, billService, threeWayMatchService, currencyService,
                commentService, documentSnapshotService);

        orgId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());

        org = Organisation.builder().name("Test Corp").build();
        org.setId(orgId);

        vendorA = Contact.builder().displayName("Vendor A").contactType(ContactType.VENDOR)
                .outstandingAp(new BigDecimal("1000")).build();
        vendorA.setId(UUID.randomUUID());
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void recordPayment_rejectsAllocationToAnotherVendorsBill() {
        UUID otherVendorId = UUID.randomUUID();
        UUID paidThroughId = UUID.randomUUID();
        UUID billId = UUID.randomUUID();

        // Bill belongs to a DIFFERENT vendor than the payment.
        PurchaseBill foreignBill = PurchaseBill.builder()
                .orgId(orgId).contactId(otherVendorId).billNumber("BILL-9")
                .status("OPEN").totalAmount(new BigDecimal("500"))
                .balanceDue(new BigDecimal("500")).exchangeRate(BigDecimal.ONE).build();
        foreignBill.setId(billId);

        Account cash = Account.builder().code("1010").build();
        cash.setId(paidThroughId);

        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(vendorA.getId(), orgId))
                .thenReturn(Optional.of(vendorA));
        when(accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, paidThroughId))
                .thenReturn(Optional.of(cash));
        when(billRepository.findByIdAndOrgIdForUpdate(billId, orgId))
                .thenReturn(Optional.of(foreignBill));

        var req = new VendorPaymentRequest(vendorA.getId(), new BigDecimal("500"), "CASH",
                LocalDate.of(2026, 5, 1), paidThroughId, null, null, null, null, null,
                List.of(new VendorPaymentRequest.AllocationRequest(billId, new BigDecimal("500"))));

        BusinessException ex = assertThrows(BusinessException.class, () -> service.recordPayment(req));
        assertEquals("AP_ALLOCATION_WRONG_VENDOR", ex.getErrorCode());
        verify(postingEngine, never()).postVendorPayment(any(), any(), any(), any(), any(), any(), any(), anyList());
    }

    @Test
    void voidPayment_restoresBalanceNetOfTds() {
        UUID billId = UUID.randomUUID();
        // Bill total 100, TDS 10 → vendor owed 90; fully paid → PAID, balanceDue 0.
        PurchaseBill bill = PurchaseBill.builder()
                .orgId(orgId).contactId(vendorA.getId()).billNumber("BILL-1")
                .status("PAID").totalAmount(new BigDecimal("100")).tdsAmount(new BigDecimal("10"))
                .amountPaid(new BigDecimal("90")).balanceDue(BigDecimal.ZERO).build();
        bill.setId(billId);

        VendorPayment payment = VendorPayment.builder()
                .orgId(orgId).contactId(vendorA.getId()).paymentNumber("VPAY-1")
                .amount(new BigDecimal("90")).build();
        payment.setId(UUID.randomUUID());
        payment.setJournalEntryId(UUID.randomUUID());
        payment.addAllocation(VendorPaymentAllocation.builder()
                .purchaseBillId(billId).amountApplied(new BigDecimal("90")).build());

        when(paymentRepository.findByIdAndOrgIdAndIsDeletedFalse(payment.getId(), orgId))
                .thenReturn(Optional.of(payment));
        when(billRepository.findById(billId)).thenReturn(Optional.of(bill));
        when(paymentRepository.save(any(VendorPayment.class))).thenAnswer(inv -> inv.getArgument(0));
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(vendorA.getId(), orgId))
                .thenReturn(Optional.of(vendorA));
        when(contactRepository.findById(vendorA.getId())).thenReturn(Optional.of(vendorA));

        service.voidPayment(payment.getId());

        // balanceDue restored to total − TDS = 90, NOT the full 100.
        assertEquals(0, new BigDecimal("90").compareTo(bill.getBalanceDue()));
        assertEquals(0, BigDecimal.ZERO.compareTo(bill.getAmountPaid()));
        assertEquals("OPEN", bill.getStatus());
        verify(journalService).reverseEntry(payment.getJournalEntryId());
    }
}
