package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.DcrReport;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface DcrReportRepository extends JpaRepository<DcrReport, UUID> {

    Optional<DcrReport> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Optional<DcrReport> findByOrgIdAndSalespersonIdAndReportDateAndIsDeletedFalse(
            UUID orgId, UUID salespersonId, LocalDate reportDate);

    List<DcrReport> findByOrgIdAndSalespersonIdAndReportDateBetweenAndIsDeletedFalseOrderByReportDateDesc(
            UUID orgId, UUID salespersonId, LocalDate from, LocalDate to);

    List<DcrReport> findByOrgIdAndStatusAndIsDeletedFalseOrderByReportDateDesc(
            UUID orgId, String status);
}
