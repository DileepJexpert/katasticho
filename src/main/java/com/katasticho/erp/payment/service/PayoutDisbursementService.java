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
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class PayoutDisbursementService {

    private static final String STATUS_PROCESSED = "PROCESSED";
    private static final String STATUS_ACCOUNTING_FAILED = "ACCOUNTING_FAILED";

    private final PayoutDisbursementRepository payoutRepository;
    private final PayoutGatewayClient gatewayClient;
    private final ContactRepository contactRepository;
    private final VendorPaymentService vendorPaymentService;

    @Transactional
    public PayoutDisbursementResponse disburse(PayoutDisbursementRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Contact contact = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(request.contactId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", request.contactId()));

        String beneficiaryName = request.beneficiaryName() != null && !request.beneficiaryName().isBlank()
                ? request.beneficiaryName()
                : (contact.getDisplayName() != null ? contact.getDisplayName() : contact.getCompanyName());

        String accountNumber = request.accountNumber() != null ? request.accountNumber() : contact.getBankAccountNo();
        String ifscCode = request.ifscCode() != null ? request.ifscCode() : contact.getBankIfsc();
        String vpa = request.vpa() != null ? request.vpa() : contact.getUpiId();
        String payoutMode = request.payoutMode() != null ? request.payoutMode().toUpperCase() : "IMPS";

        if ((accountNumber == null || accountNumber.isBlank() || ifscCode == null || ifscCode.isBlank())
                && (vpa == null || vpa.isBlank())) {
            throw new BusinessException(
                    "Beneficiary bank details (Account + IFSC or UPI ID) are required for payout disbursement",
                    "PAYOUT_MISSING_BANK_DETAILS",
                    HttpStatus.BAD_REQUEST
            );
        }

        // Call Gateway Client
        PayoutGatewayClient.PayoutGatewayResult gwResult = gatewayClient.disburse(
                orgId,
                request.amount(),
                "INR",
                payoutMode,
                beneficiaryName,
                accountNumber,
                ifscCode,
                vpa,
                request.narration()
        );

        PayoutDisbursement payout = PayoutDisbursement.builder()
                .orgId(orgId)
                .provider("RAZORPAYX")
                .providerPayoutId(gwResult.providerPayoutId())
                .utr(gwResult.utr())
                .status(gwResult.status())
                .contactId(contact.getId())
                .amount(request.amount())
                .currency("INR")
                .payoutMode(payoutMode)
                .beneficiaryName(beneficiaryName)
                .accountNumber(accountNumber)
                .ifscCode(ifscCode)
                .vpa(vpa)
                .failureReason(gwResult.failureReason())
                .build();

        payout = payoutRepository.save(payout);

        // If disbursement succeeded and bill allocations are provided, automatically book vendor payment & journal
        if (gwResult.success() && request.billAllocations() != null && !request.billAllocations().isEmpty()) {
            try {
                List<VendorPaymentRequest.AllocationRequest> allocations = request.billAllocations().stream()
                        .map(a -> new VendorPaymentRequest.AllocationRequest(a.billId(), a.amountApplied()))
                        .toList();

                VendorPaymentRequest vpReq = new VendorPaymentRequest(
                        contact.getId(),
                        request.amount(),
                        "BANK_TRANSFER",
                        LocalDate.now(),
                        request.paidThroughAccountId(),
                        gwResult.utr() != null ? gwResult.utr() : payout.getProviderPayoutId(),
                        null,
                        null,
                        "Direct Gateway Disbursement - UTR: " + gwResult.utr(),
                        null,
                        allocations
                );

                VendorPaymentResponse vpRes = vendorPaymentService.recordPayment(vpReq);
                payout.setVendorPaymentId(vpRes.id());
                payout = payoutRepository.save(payout);
                log.info("[PayoutDisbursementService] Successfully booked vendor payment {} for payout {}",
                        vpRes.id(), payout.getId());
            } catch (Exception e) {
                log.error("[PayoutDisbursementService] Payout {} succeeded but recording vendor payment failed: {}",
                        payout.getId(), e.getMessage());
                payout.setStatus(STATUS_ACCOUNTING_FAILED);
                payout.setFailureReason("Payout disbursed via UTR " + (gwResult.utr() != null ? gwResult.utr() : payout.getProviderPayoutId())
                        + " but AP vendor payment booking failed: " + e.getMessage());
                payout = payoutRepository.save(payout);
            }
        }

        return toResponse(payout, contact.getDisplayName());
    }

    @Transactional
    public PayoutDisbursementResponse reconcileAccounting(UUID payoutId, UUID paidThroughAccountId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        PayoutDisbursement payout = payoutRepository.findByIdAndOrgIdAndDeletedFalseForUpdate(payoutId, orgId)
                .orElseThrow(() -> BusinessException.notFound("PayoutDisbursement", payoutId));

        if (payout.getVendorPaymentId() != null) {
            throw new BusinessException("Vendor payment is already booked for payout " + payoutId,
                    "ALREADY_BOOKED", org.springframework.http.HttpStatus.CONFLICT);
        }

        if (!isProviderConfirmed(payout)) {
            throw new BusinessException(
                    "Only a provider-confirmed payout can be reconciled into accounts",
                    "PAYOUT_NOT_SETTLED", org.springframework.http.HttpStatus.CONFLICT);
        }

        UUID targetContactId = payout.getContactId();
        Contact contact = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(targetContactId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", targetContactId));

        VendorPaymentRequest vpReq = new VendorPaymentRequest(
                contact.getId(),
                payout.getAmount(),
                "BANK_TRANSFER",
                LocalDate.now(),
                paidThroughAccountId,
                payout.getUtr() != null ? payout.getUtr() : payout.getProviderPayoutId(),
                null,
                null,
                "Reconciled Gateway Disbursement - UTR: " + payout.getUtr(),
                null,
                List.of()
        );

        VendorPaymentResponse vpRes = vendorPaymentService.recordPayment(vpReq);
        payout.setVendorPaymentId(vpRes.id());
        payout.setStatus(STATUS_PROCESSED);
        payout.setFailureReason(null);
        payout = payoutRepository.save(payout);

        return toResponse(payout, contact.getDisplayName());
    }

    @Transactional(readOnly = true)
    public Page<PayoutDisbursementResponse> listPayouts(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return payoutRepository.findByOrgIdAndDeletedFalseOrderByCreatedAtDesc(orgId, pageable)
                .map(p -> {
                    String contactName = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(p.getContactId(), orgId)
                            .map(Contact::getDisplayName).orElse("Vendor");
                    return toResponse(p, contactName);
                });
    }

    private PayoutDisbursementResponse toResponse(PayoutDisbursement p, String contactName) {
        String maskedAcc = null;
        if (p.getAccountNumber() != null && p.getAccountNumber().length() > 4) {
            maskedAcc = "••••" + p.getAccountNumber().substring(p.getAccountNumber().length() - 4);
        } else if (p.getVpa() != null) {
            maskedAcc = p.getVpa();
        }

        return new PayoutDisbursementResponse(
                p.getId(),
                p.getProvider(),
                p.getProviderPayoutId(),
                p.getUtr(),
                p.getStatus(),
                p.getContactId(),
                contactName,
                p.getAmount(),
                p.getCurrency(),
                p.getPayoutMode(),
                p.getBeneficiaryName(),
                maskedAcc,
                p.getIfscCode(),
                p.getVpa(),
                p.getVendorPaymentId(),
                p.getFailureReason(),
                p.getCreatedAt()
        );
    }

    private boolean isProviderConfirmed(PayoutDisbursement payout) {
        boolean successfulProviderStatus = STATUS_PROCESSED.equalsIgnoreCase(payout.getStatus())
                || STATUS_ACCOUNTING_FAILED.equalsIgnoreCase(payout.getStatus());
        return successfulProviderStatus
                && payout.getProviderPayoutId() != null
                && !payout.getProviderPayoutId().isBlank();
    }
}
