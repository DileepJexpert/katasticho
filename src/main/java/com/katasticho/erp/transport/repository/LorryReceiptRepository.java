package com.katasticho.erp.transport.repository;

import com.katasticho.erp.transport.entity.LorryReceipt;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface LorryReceiptRepository extends JpaRepository<LorryReceipt, UUID> {

    Optional<LorryReceipt> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<LorryReceipt> findByOrgIdAndIsDeletedFalseOrderByLrDateDesc(UUID orgId);

    List<LorryReceipt> findByOrgIdAndStatusAndIsDeletedFalseOrderByLrDateDesc(UUID orgId, String status);

    long countByOrgIdAndIsDeletedFalse(UUID orgId);
}
