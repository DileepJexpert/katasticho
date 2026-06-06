package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.SalesmanTarget;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Repository
public interface SalesmanTargetRepository extends JpaRepository<SalesmanTarget, UUID> {

    List<SalesmanTarget> findByOrgIdAndSalespersonIdAndIsDeletedFalse(UUID orgId, UUID salespersonId);

    List<SalesmanTarget> findByOrgIdAndSalespersonIdAndPeriodTypeAndPeriodStartAndIsDeletedFalse(
            UUID orgId, UUID salespersonId, String periodType, LocalDate periodStart);

    Page<SalesmanTarget> findByOrgIdAndIsDeletedFalse(UUID orgId, Pageable pageable);
}
