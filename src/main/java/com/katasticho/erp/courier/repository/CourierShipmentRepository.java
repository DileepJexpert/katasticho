package com.katasticho.erp.courier.repository;

import com.katasticho.erp.courier.entity.CourierShipment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CourierShipmentRepository extends JpaRepository<CourierShipment, UUID> {

    Optional<CourierShipment> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<CourierShipment> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId);

    List<CourierShipment> findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, String status);

    /** AWB lookup for inbound webhooks (we know the partner) and COD remittance match. */
    Optional<CourierShipment> findFirstByOrgIdAndCourierPartnerAndAwbNumberAndIsDeletedFalse(
            UUID orgId, String courierPartner, String awbNumber);

    /** Fallback when a remittance file omits the courier name. */
    Optional<CourierShipment> findFirstByOrgIdAndAwbNumberAndIsDeletedFalse(UUID orgId, String awbNumber);

    long countByOrgIdAndIsDeletedFalse(UUID orgId);
}
