package com.katasticho.erp.courier.repository;

import com.katasticho.erp.courier.entity.CourierShipmentEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface CourierShipmentEventRepository extends JpaRepository<CourierShipmentEvent, UUID> {

    List<CourierShipmentEvent> findByOrgIdAndCourierShipmentIdOrderByEventAtDesc(
            UUID orgId, UUID courierShipmentId);
}
