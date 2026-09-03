package com.katasticho.erp.inventory.putaway.repository;

import com.katasticho.erp.inventory.putaway.entity.WarehousePutawayLine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface WarehousePutawayLineRepository extends JpaRepository<WarehousePutawayLine, UUID> {
    List<WarehousePutawayLine> findByTaskId(UUID taskId);
}