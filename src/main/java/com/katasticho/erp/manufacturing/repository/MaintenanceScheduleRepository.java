package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.MaintenanceSchedule;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface MaintenanceScheduleRepository extends JpaRepository<MaintenanceSchedule, UUID> {

    Optional<MaintenanceSchedule> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Optional<MaintenanceSchedule> findByOrgIdAndCodeAndIsDeletedFalse(UUID orgId, String code);

    List<MaintenanceSchedule> findByOrgIdAndIsDeletedFalseOrderByNextDueDateAsc(UUID orgId);

    List<MaintenanceSchedule> findByOrgIdAndIsDeletedFalseAndActiveTrueAndNextDueDateLessThanEqualOrderByNextDueDateAsc(
            UUID orgId, LocalDate cutoff);

    List<MaintenanceSchedule> findByOrgIdAndWorkstationIdAndIsDeletedFalseOrderByNextDueDateAsc(
            UUID orgId, UUID workstationId);
}
