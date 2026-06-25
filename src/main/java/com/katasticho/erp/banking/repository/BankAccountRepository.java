package com.katasticho.erp.banking.repository;

import com.katasticho.erp.banking.entity.BankAccount;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BankAccountRepository extends JpaRepository<BankAccount, UUID> {

    Optional<BankAccount> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<BankAccount> findByOrgIdAndIsDeletedFalseOrderByIsDefaultDescNameAsc(UUID orgId);

    List<BankAccount> findByOrgIdAndIsActiveTrueAndIsDeletedFalseOrderByIsDefaultDescNameAsc(UUID orgId);

    Optional<BankAccount> findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(UUID orgId);

    boolean existsByOrgIdAndAccountNumberAndIsDeletedFalse(UUID orgId, String accountNumber);

    /** Live default-flagged accounts other than {@code excludeId} — cleared when a new default is set. */
    @Query("""
        SELECT b FROM BankAccount b
        WHERE b.orgId = :orgId
          AND b.isDefault = true
          AND b.isDeleted = false
          AND (:excludeId IS NULL OR b.id <> :excludeId)
    """)
    List<BankAccount> findOtherDefaults(@Param("orgId") UUID orgId, @Param("excludeId") UUID excludeId);
}
