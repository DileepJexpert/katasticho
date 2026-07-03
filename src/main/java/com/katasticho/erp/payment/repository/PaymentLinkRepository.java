package com.katasticho.erp.payment.repository;

import com.katasticho.erp.payment.entity.PaymentLink;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface PaymentLinkRepository extends JpaRepository<PaymentLink, UUID> {

    List<PaymentLink> findByOrgIdAndInvoiceIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, UUID invoiceId);

    Optional<PaymentLink> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Optional<PaymentLink> findByProviderAndProviderLinkIdAndIsDeletedFalse(String provider, String providerLinkId);

    Optional<PaymentLink> findByProviderAndProviderPaymentIdAndIsDeletedFalse(String provider, String providerPaymentId);

    /** Most recent link for an invoice — a webhook may resolve by invoice number when many links exist. */
    Optional<PaymentLink> findFirstByOrgIdAndReferenceIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, String referenceId);

    /**
     * Pessimistic write lock on a link row — serialises concurrent settlement
     * events for the same capture (Razorpay sends both payment.captured and
     * payment_link.paid), so the second blocks until the first has stamped the
     * link PAID, then sees it settled and no-ops.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<PaymentLink> findByIdAndIsDeletedFalse(UUID id);
}
