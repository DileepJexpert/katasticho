package com.katasticho.erp.payment.repository;

import com.katasticho.erp.payment.entity.PayoutDisbursement;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface PayoutDisbursementRepository extends JpaRepository<PayoutDisbursement, UUID> {

    Page<PayoutDisbursement> findByOrgIdAndDeletedFalseOrderByCreatedAtDesc(UUID orgId, Pageable pageable);

    Optional<PayoutDisbursement> findByIdAndOrgIdAndDeletedFalse(UUID id, UUID orgId);

    Optional<PayoutDisbursement> findByOrgIdAndProviderPayoutIdAndDeletedFalse(UUID orgId, String providerPayoutId);

    Optional<PayoutDisbursement> findByOrgIdAndUtrAndDeletedFalse(UUID orgId, String utr);
}
