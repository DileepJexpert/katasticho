package com.katasticho.erp.inventory.consignment.repository;

import com.katasticho.erp.inventory.consignment.entity.ConsignmentSettlement;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface ConsignmentSettlementRepository extends JpaRepository<ConsignmentSettlement, UUID> {

    /** Per-org MAX+1 sequence for settlement numbers (offset LENGTH(prefix)+2 matches CS-YYYY-NNNNNN). */
    @Query("SELECT COALESCE(MAX(CAST(SUBSTRING(s.settlementNumber, LENGTH(:prefix) + 2) AS int)), 0) + 1 "
            + "FROM ConsignmentSettlement s WHERE s.orgId = :orgId AND s.settlementNumber LIKE CONCAT(:prefix, '-%')")
    int nextSequence(UUID orgId, String prefix);

    List<ConsignmentSettlement> findByOrgIdAndConsignmentStockIdAndIsDeletedFalse(
            UUID orgId, UUID consignmentStockId);

    List<ConsignmentSettlement> findByOrgIdAndStatusAndIsDeletedFalse(UUID orgId, String status);

    /** Unsettled (DRAFT) settlements for all consignment stocks belonging to a supplier. */
    List<ConsignmentSettlement> findByOrgIdAndConsignmentStockIdInAndStatusAndIsDeletedFalse(
            UUID orgId, List<UUID> consignmentStockIds, String status);
}
