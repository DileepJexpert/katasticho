package com.katasticho.erp.inventory.consignment.repository;

import com.katasticho.erp.inventory.consignment.entity.ConsignmentSettlement;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface ConsignmentSettlementRepository extends JpaRepository<ConsignmentSettlement, UUID> {

    List<ConsignmentSettlement> findByOrgIdAndConsignmentStockIdAndIsDeletedFalse(
            UUID orgId, UUID consignmentStockId);

    List<ConsignmentSettlement> findByOrgIdAndStatusAndIsDeletedFalse(UUID orgId, String status);

    /** Unsettled (DRAFT) settlements for all consignment stocks belonging to a supplier. */
    List<ConsignmentSettlement> findByOrgIdAndConsignmentStockIdInAndStatusAndIsDeletedFalse(
            UUID orgId, List<UUID> consignmentStockIds, String status);
}
