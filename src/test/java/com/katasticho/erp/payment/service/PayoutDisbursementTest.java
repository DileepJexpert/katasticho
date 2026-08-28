package com.katasticho.erp.payment.service;

import com.katasticho.erp.ap.dto.VendorPaymentRequest;
import com.katasticho.erp.ap.dto.VendorPaymentResponse;
import com.katasticho.erp.ap.service.VendorPaymentService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.payment.dto.PayoutDisbursementRequest;
import com.katasticho.erp.payment.dto.PayoutDisbursementResponse;
import com.katasticho.erp.payment.entity.PayoutDisbursement;
import com.katasticho.erp.payment.repository.PayoutDisbursementRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PayoutDisbursementTest {

    @Mock
    private PayoutDisbursementRepository payoutRepository;

    @Mock
    private PayoutGatewayClient gatewayClient;

    @Mock
    private ContactRepository contactRepository;

    @Mock
    private VendorPaymentService vendorPaymentService;

    @InjectMocks
    private PayoutDisbursementService disbursementService;

    private UUID orgId;
    private UUID contactId;
    private UUID bankAccountId;
    private UUID billId;

    @BeforeEach
    void setUp() {
        orgId = UUID.randomUUID();
        contactId = UUID.randomUUID();
        bankAccountId = UUID.randomUUID();
        billId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void disburse_success_without_allocations() {
        Contact vendor = Contact.builder()
                .displayName("Cipla Pharma Distributors")
                .bankAccountNo("987654321012")
                .bankIfsc("HDFC0001234")
                .build();
        vendor.setId(contactId);

        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(vendor));

        when(gatewayClient.disburse(eq(orgId), any(), eq("INR"), eq("IMPS"), any(), any(), any(), any(), any()))
                .thenReturn(new PayoutGatewayClient.PayoutGatewayResult(
                        true, "pout_12345", "UTR99887766", "PROCESSED", null));

        when(payoutRepository.save(any(PayoutDisbursement.class)))
                .thenAnswer(inv -> {
                    PayoutDisbursement p = inv.getArgument(0);
                    p.setId(UUID.randomUUID());
                    return p;
                });

        PayoutDisbursementRequest req = new PayoutDisbursementRequest(
                contactId,
                new BigDecimal("25000.00"),
                bankAccountId,
                "IMPS",
                null,
                null,
                null,
                null,
                "Advance supplier payment",
                null
        );

        PayoutDisbursementResponse res = disbursementService.disburse(req);

        assertThat(res).isNotNull();
        assertThat(res.status()).isEqualTo("PROCESSED");
        assertThat(res.utr()).isEqualTo("UTR99887766");
        assertThat(res.beneficiaryName()).isEqualTo("Cipla Pharma Distributors");
        assertThat(res.accountNumberMasked()).isEqualTo("••••1012");
        assertThat(res.amount()).isEqualByComparingTo("25000.00");
        verify(vendorPaymentService, never()).recordPayment(any());
    }

    @Test
    void disburse_success_with_bill_allocations_books_vendor_payment() {
        Contact vendor = Contact.builder()
                .displayName("Sun Pharma Logistics")
                .bankAccountNo("112233445566")
                .bankIfsc("SBIN0004321")
                .build();
        vendor.setId(contactId);

        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(vendor));

        when(gatewayClient.disburse(eq(orgId), any(), eq("INR"), eq("NEFT"), any(), any(), any(), any(), any()))
                .thenReturn(new PayoutGatewayClient.PayoutGatewayResult(
                        true, "pout_9988", "UTR55443322", "PROCESSED", null));

        when(payoutRepository.save(any(PayoutDisbursement.class)))
                .thenAnswer(inv -> {
                    PayoutDisbursement p = inv.getArgument(0);
                    if (p.getId() == null) p.setId(UUID.randomUUID());
                    return p;
                });

        UUID paymentId = UUID.randomUUID();
        VendorPaymentResponse vpRes = new VendorPaymentResponse(
                paymentId,
                contactId,
                "Sun Pharma Logistics",
                "VP-2026-001",
                LocalDate.now(),
                new BigDecimal("50000.00"),
                "INR",
                "BANK_TRANSFER",
                bankAccountId,
                "UTR55443322",
                BigDecimal.ZERO,
                "Direct Gateway Disbursement - UTR: UTR55443322",
                UUID.randomUUID(),
                List.of(),
                Instant.now()
        );

        when(vendorPaymentService.recordPayment(any(VendorPaymentRequest.class)))
                .thenReturn(vpRes);

        PayoutDisbursementRequest req = new PayoutDisbursementRequest(
                contactId,
                new BigDecimal("50000.00"),
                bankAccountId,
                "NEFT",
                null,
                null,
                null,
                null,
                "Settling Invoice INV-8899",
                List.of(new PayoutDisbursementRequest.BillAllocation(billId, new BigDecimal("50000.00")))
        );

        PayoutDisbursementResponse res = disbursementService.disburse(req);

        assertThat(res).isNotNull();
        assertThat(res.vendorPaymentId()).isEqualTo(paymentId);
        verify(vendorPaymentService, times(1)).recordPayment(any(VendorPaymentRequest.class));
    }

    @Test
    void disburse_missing_bank_details_throwsException() {
        Contact vendorWithoutBank = Contact.builder()
                .displayName("Vendor Without Bank")
                .build();
        vendorWithoutBank.setId(contactId);

        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(vendorWithoutBank));

        PayoutDisbursementRequest req = new PayoutDisbursementRequest(
                contactId,
                new BigDecimal("1000.00"),
                bankAccountId,
                "IMPS",
                null,
                null,
                null,
                null,
                null,
                null
        );

        assertThatThrownBy(() -> disbursementService.disburse(req))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("Beneficiary bank details");
    }

    @Test
    void disburse_accounting_failure_marks_status_ACCOUNTING_FAILED() {
        Contact vendor = Contact.builder()
                .displayName("Sun Pharma Logistics")
                .bankAccountNo("112233445566")
                .bankIfsc("SBIN0004321")
                .build();
        vendor.setId(contactId);

        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(vendor));

        when(gatewayClient.disburse(eq(orgId), any(), eq("INR"), eq("NEFT"), any(), any(), any(), any(), any()))
                .thenReturn(new PayoutGatewayClient.PayoutGatewayResult(
                        true, "pout_9988", "UTR55443322", "PROCESSED", null));

        when(payoutRepository.save(any(PayoutDisbursement.class)))
                .thenAnswer(inv -> {
                    PayoutDisbursement p = inv.getArgument(0);
                    if (p.getId() == null) p.setId(UUID.randomUUID());
                    return p;
                });

        when(vendorPaymentService.recordPayment(any(VendorPaymentRequest.class)))
                .thenThrow(new RuntimeException("Lock timeout on invoice balance"));

        PayoutDisbursementRequest req = new PayoutDisbursementRequest(
                contactId,
                new BigDecimal("50000.00"),
                bankAccountId,
                "NEFT",
                null,
                null,
                null,
                null,
                "Settling Invoice INV-8899",
                List.of(new PayoutDisbursementRequest.BillAllocation(billId, new BigDecimal("50000.00")))
        );

        PayoutDisbursementResponse res = disbursementService.disburse(req);

        assertThat(res).isNotNull();
        assertThat(res.status()).isEqualTo("ACCOUNTING_FAILED");
        assertThat(res.vendorPaymentId()).isNull();
        assertThat(res.failureReason()).contains("AP vendor payment booking failed");
    }

    @Test
    void reconcileAccounting_success() {
        UUID payoutId = UUID.randomUUID();
        PayoutDisbursement payout = PayoutDisbursement.builder()
                .orgId(orgId)
                .contactId(contactId)
                .amount(new BigDecimal("30000.00"))
                .status("ACCOUNTING_FAILED")
                .utr("UTR11223344")
                .providerPayoutId("pout_7766")
                .build();
        payout.setId(payoutId);

        Contact vendor = Contact.builder()
                .displayName("Sun Pharma Logistics")
                .build();
        vendor.setId(contactId);

        when(payoutRepository.findById(payoutId)).thenReturn(Optional.of(payout));
        when(contactRepository.findById(contactId)).thenReturn(Optional.of(vendor));

        UUID paymentId = UUID.randomUUID();
        VendorPaymentResponse vpRes = new VendorPaymentResponse(
                paymentId, contactId, "Sun Pharma Logistics", "VP-2026-002", LocalDate.now(),
                new BigDecimal("30000.00"), "INR", "BANK_TRANSFER", bankAccountId, "UTR11223344",
                BigDecimal.ZERO, "Reconciled", UUID.randomUUID(), List.of(), Instant.now()
        );
        when(vendorPaymentService.recordPayment(any())).thenReturn(vpRes);
        when(payoutRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        PayoutDisbursementResponse res = disbursementService.reconcileAccounting(payoutId, bankAccountId);

        assertThat(res).isNotNull();
        assertThat(res.status()).isEqualTo("PROCESSED");
        assertThat(res.vendorPaymentId()).isEqualTo(paymentId);
    }
}
