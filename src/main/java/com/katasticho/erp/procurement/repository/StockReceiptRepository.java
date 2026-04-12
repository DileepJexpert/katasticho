package com.katasticho.erp.procurement.repository;

import com.katasticho.erp.procurement.entity.StockReceipt;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface StockReceiptRepository extends JpaRepository<StockReceipt, UUID> {

    Optional<StockReceipt> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<StockReceipt> findByOrgIdAndIsDeletedFalseOrderByReceiptDateDesc(UUID orgId, Pageable pageable);

    Page<StockReceipt> findByOrgIdAndSupplierIdAndIsDeletedFalseOrderByReceiptDateDesc(
            UUID orgId, UUID supplierId, Pageable pageable);
}
