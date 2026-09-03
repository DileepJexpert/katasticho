package com.katasticho.erp.payment.repository;

import com.katasticho.erp.payment.entity.PayoutDisbursement;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import jakarta.persistence.LockModeType;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface PayoutDisbursementRepository extends JpaRepository<PayoutDisbursement, UUID> {

    Page<PayoutDisbursement> findByOrgIdAndDeletedFalseOrderByCreatedAtDesc(UUID orgId, Pageable pageable);

    Optional<PayoutDisbursement> findByIdAndOrgIdAndDeletedFalse(UUID id, UUID orgId);

    /**
     * Serializes the check-and-book transition so one confirmed payout can
     * create at most one vendor payment.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
            select p from PayoutDisbursement p
            where p.id = :id and p.orgId = :orgId and p.deleted = false
            """)
    Optional<PayoutDisbursement> findByIdAndOrgIdAndDeletedFalseForUpdate(UUID id, UUID orgId);

    Optional<PayoutDisbursement> findByOrgIdAndProviderPayoutIdAndDeletedFalse(UUID orgId, String providerPayoutId);

    Optional<PayoutDisbursement> findByOrgIdAndUtrAndDeletedFalse(UUID orgId, String utr);
}
