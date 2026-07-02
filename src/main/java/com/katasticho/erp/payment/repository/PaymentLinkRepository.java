package com.katasticho.erp.payment.repository;

import com.katasticho.erp.payment.entity.PaymentLink;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface PaymentLinkRepository extends JpaRepository<PaymentLink, UUID> {

    List<PaymentLink> findByOrgIdAndInvoiceIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, UUID invoiceId);

    Optional<PaymentLink> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Optional<PaymentLink> findByProviderAndProviderLinkIdAndIsDeletedFalse(String provider, String providerLinkId);

    Optional<PaymentLink> findByProviderAndProviderPaymentIdAndIsDeletedFalse(String provider, String providerPaymentId);

    Optional<PaymentLink> findByOrgIdAndReferenceIdAndIsDeletedFalse(UUID orgId, String referenceId);
}
