package com.katasticho.erp.supplychain.repository;

import com.katasticho.erp.supplychain.entity.ShipmentLine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface ShipmentLineRepository extends JpaRepository<ShipmentLine, UUID> {

    List<ShipmentLine> findByOrgIdAndShipmentIdAndIsDeletedFalse(UUID orgId, UUID shipmentId);
}
