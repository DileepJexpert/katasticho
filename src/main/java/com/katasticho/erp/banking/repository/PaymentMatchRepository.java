package com.katasticho.erp.banking.repository;

import com.katasticho.erp.banking.entity.PaymentMatch;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface PaymentMatchRepository extends JpaRepository<PaymentMatch, UUID> {

    List<PaymentMatch> findByOrgIdAndBankTransactionIdInOrderByConfidenceDesc(UUID orgId, Collection<UUID> bankTransactionIds);

    List<PaymentMatch> findByOrgIdAndBankTransactionIdOrderByConfidenceDesc(UUID orgId, UUID bankTransactionId);

    Optional<PaymentMatch> findByIdAndOrgId(UUID id, UUID orgId);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
        DELETE FROM PaymentMatch pm
        WHERE pm.orgId = :orgId
          AND pm.bankTransactionId = :bankTransactionId
          AND pm.matchStatus = :matchStatus
    """)
    int deleteByOrgIdAndBankTransactionIdAndMatchStatus(UUID orgId, UUID bankTransactionId, String matchStatus);
}
