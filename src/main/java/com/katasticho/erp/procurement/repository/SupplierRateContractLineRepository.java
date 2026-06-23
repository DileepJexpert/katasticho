package com.katasticho.erp.procurement.repository;

import com.katasticho.erp.procurement.entity.SupplierRateContractLine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface SupplierRateContractLineRepository
        extends JpaRepository<SupplierRateContractLine, UUID> {

    List<SupplierRateContractLine> findBySupplierRateContractIdAndIsDeletedFalseOrderByCreatedAtAsc(
            UUID contractId);

    /**
     * Resolve the active negotiated unit price for (org, supplier, item).
     * Returns at most one row — the application's activate() guard refuses
     * to land a second ACTIVE contract for the same triplet.
     */
    @Query("""
        SELECT l FROM SupplierRateContractLine l
        WHERE l.orgId = :orgId
          AND l.itemId = :itemId
          AND l.isDeleted = false
          AND l.supplierRateContractId IN (
              SELECT c.id FROM SupplierRateContract c
              WHERE c.orgId = :orgId
                AND c.supplierContactId = :supplierContactId
                AND c.status = 'ACTIVE'
                AND c.isDeleted = false)
    """)
    Optional<SupplierRateContractLine> findActiveLine(
            UUID orgId, UUID supplierContactId, UUID itemId);
}
