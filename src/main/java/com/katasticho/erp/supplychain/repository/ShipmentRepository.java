package com.katasticho.erp.supplychain.repository;

import com.katasticho.erp.supplychain.entity.Shipment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ShipmentRepository extends JpaRepository<Shipment, UUID> {

    Optional<Shipment> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<Shipment> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId);

    List<Shipment> findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, String status);

    List<Shipment> findByOrgIdAndShipmentTypeAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, String shipmentType);

    List<Shipment> findByOrgIdAndStatusAndShipmentTypeAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, String status, String shipmentType);

    long countByOrgIdAndIsDeletedFalse(UUID orgId);
}
