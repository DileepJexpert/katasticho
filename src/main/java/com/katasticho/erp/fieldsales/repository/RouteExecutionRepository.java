package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.RouteExecution;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface RouteExecutionRepository extends JpaRepository<RouteExecution, UUID> {

    Optional<RouteExecution> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<RouteExecution> findByOrgIdAndExecutionDateAndIsDeletedFalse(UUID orgId, LocalDate date);

    Page<RouteExecution> findByOrgIdAndSalespersonIdAndIsDeletedFalse(UUID orgId, UUID salespersonId, Pageable pageable);

    Page<RouteExecution> findByOrgIdAndIsDeletedFalse(UUID orgId, Pageable pageable);

    Optional<RouteExecution> findByOrgIdAndSalespersonIdAndExecutionDateAndIsDeletedFalse(UUID orgId, UUID salespersonId, LocalDate date);
}
