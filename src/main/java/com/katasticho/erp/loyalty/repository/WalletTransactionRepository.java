package com.katasticho.erp.loyalty.repository;

import com.katasticho.erp.loyalty.entity.WalletTransaction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface WalletTransactionRepository extends JpaRepository<WalletTransaction, UUID> {

    List<WalletTransaction> findByOrgIdAndContactIdOrderByCreatedAtDesc(UUID orgId, UUID contactId);

    List<WalletTransaction> findByOrgIdAndWalletIdOrderByCreatedAtDesc(UUID orgId, UUID walletId);
}
