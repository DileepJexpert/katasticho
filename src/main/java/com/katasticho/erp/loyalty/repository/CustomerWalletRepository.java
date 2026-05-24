package com.katasticho.erp.loyalty.repository;

import com.katasticho.erp.loyalty.entity.CustomerWallet;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CustomerWalletRepository extends JpaRepository<CustomerWallet, UUID> {

    Optional<CustomerWallet> findByOrgIdAndContactIdAndIsDeletedFalse(UUID orgId, UUID contactId);

    List<CustomerWallet> findByOrgIdAndIsDeletedFalseOrderByBalanceDesc(UUID orgId);
}
