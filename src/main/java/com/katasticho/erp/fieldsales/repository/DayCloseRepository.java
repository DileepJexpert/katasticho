package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.DayClose;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface DayCloseRepository extends JpaRepository<DayClose, UUID> {

    Optional<DayClose> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Optional<DayClose> findByOrgIdAndRouteExecutionIdAndIsDeletedFalse(UUID orgId, UUID routeExecutionId);

    Page<DayClose> findByOrgIdAndSalespersonIdAndIsDeletedFalse(UUID orgId, UUID salespersonId, Pageable pageable);

    List<DayClose> findByOrgIdAndCloseDateAndIsDeletedFalse(UUID orgId, LocalDate closeDate);
}
