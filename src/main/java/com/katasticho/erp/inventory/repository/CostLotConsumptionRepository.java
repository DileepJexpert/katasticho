package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.CostLotConsumption;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface CostLotConsumptionRepository extends JpaRepository<CostLotConsumption, UUID> {

    List<CostLotConsumption> findByMovementId(UUID movementId);

    void deleteByMovementId(UUID movementId);
}
