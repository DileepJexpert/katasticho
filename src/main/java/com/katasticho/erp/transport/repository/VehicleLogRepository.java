package com.katasticho.erp.transport.repository;

import com.katasticho.erp.transport.entity.VehicleLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface VehicleLogRepository extends JpaRepository<VehicleLog, UUID> {

    Optional<VehicleLog> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<VehicleLog> findByOrgIdAndIsDeletedFalseOrderByLogDateDesc(UUID orgId);

    List<VehicleLog> findByOrgIdAndVehicleNumberIgnoreCaseAndIsDeletedFalseOrderByLogDateDesc(
            UUID orgId, String vehicleNumber);
}
