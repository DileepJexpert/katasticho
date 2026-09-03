package com.katasticho.erp.inventory.putaway.repository;

import com.katasticho.erp.inventory.putaway.entity.WarehousePutawayTask;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface WarehousePutawayTaskRepository extends JpaRepository<WarehousePutawayTask, UUID> {

    List<WarehousePutawayTask> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId);

    List<WarehousePutawayTask> findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, String status);

    Optional<WarehousePutawayTask> findByOrgIdAndIdAndIsDeletedFalse(UUID orgId, UUID id);

    @Query("SELECT COUNT(t) FROM WarehousePutawayTask t WHERE t.orgId = :orgId")
    long countByOrgId(UUID orgId);
}