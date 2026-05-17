package com.katasticho.erp.banking.repository;

import com.katasticho.erp.banking.entity.BankTransaction;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
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
}
