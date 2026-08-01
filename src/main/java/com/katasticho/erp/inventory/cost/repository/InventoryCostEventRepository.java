package com.katasticho.erp.inventory.cost.repository;

import com.katasticho.erp.inventory.cost.entity.InventoryCostEvent;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface InventoryCostEventRepository extends JpaRepository<InventoryCostEvent, UUID> {
    List<InventoryCostEvent> findByOrgIdAndSourceTypeAndSourceIdAndIsDeletedFalseOrderByCreatedAtAsc(
            UUID orgId, String sourceType, UUID sourceId);

    List<InventoryCostEvent> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId);
}
