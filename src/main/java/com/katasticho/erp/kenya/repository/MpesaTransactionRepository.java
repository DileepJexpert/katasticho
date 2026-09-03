package com.katasticho.erp.kenya.repository;

import com.katasticho.erp.kenya.entity.MpesaTransaction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface MpesaTransactionRepository extends JpaRepository<MpesaTransaction, UUID> {
    List<MpesaTransaction> findByOrgIdAndIsDeletedFalseOrderByTransactionTimeDesc(UUID orgId);
    List<MpesaTransaction> findByOrgIdAndStatusAndIsDeletedFalseOrderByTransactionTimeDesc(UUID orgId, String status);
    Optional<MpesaTransaction> findByOrgIdAndMpesaReceiptNumberAndIsDeletedFalse(UUID orgId, String mpesaReceiptNumber);
    Optional<MpesaTransaction> findByOrgIdAndIdAndIsDeletedFalse(UUID orgId, UUID id);
}