package com.katasticho.erp.banking.repository;

import com.katasticho.erp.banking.entity.BankTransaction;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.math.BigDecimal;
import java.util.Collection;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface BankTransactionRepository extends JpaRepository<BankTransaction, UUID> {

    Page<BankTransaction> findByOrgIdOrderByTransactionDateDescCreatedAtDesc(UUID orgId, Pageable pageable);

    Page<BankTransaction> findByOrgIdAndStatusOrderByTransactionDateDescCreatedAtDesc(
            UUID orgId, String status, Pageable pageable);

    Optional<BankTransaction> findByIdAndOrgId(UUID id, UUID orgId);

    List<BankTransaction> findByOrgIdAndIdIn(UUID orgId, Collection<UUID> ids);

    boolean existsByOrgIdAndUtrAndDirection(UUID orgId, String utr, String direction);

    long countByOrgIdAndStatusAndTransactionDateBefore(UUID orgId, String status, LocalDate date);

    long countByOrgIdAndStatus(UUID orgId, String status);

    @Query("""
        SELECT COALESCE(SUM(t.amount), 0) FROM BankTransaction t
        WHERE t.orgId = :orgId
          AND t.direction = :direction
          AND t.status IN :statuses
    """)
    BigDecimal sumAmountByOrgIdAndDirectionAndStatuses(
            UUID orgId, String direction, Collection<String> statuses);
}
