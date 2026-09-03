package com.katasticho.erp.inventory.transit.repository;

import com.katasticho.erp.inventory.transit.entity.TransferOrderTransitEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface TransferOrderTransitEventRepository extends JpaRepository<TransferOrderTransitEvent, UUID> {
    List<TransferOrderTransitEvent> findByDispatchIdOrderByRecordedAtDesc(UUID dispatchId);
}