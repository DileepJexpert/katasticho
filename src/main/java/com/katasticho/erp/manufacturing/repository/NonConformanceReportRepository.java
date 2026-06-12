package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.NonConformanceReport;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface NonConformanceReportRepository extends JpaRepository<NonConformanceReport, UUID> {

    Optional<NonConformanceReport> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<NonConformanceReport> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, Pageable pageable);

    Page<NonConformanceReport> findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, String status, Pageable pageable);

    @Query("SELECT COALESCE(MAX(CAST(SUBSTRING(n.ncrNumber, 5) AS int)), 0) FROM NonConformanceReport n WHERE n.orgId = :orgId")
    int findMaxNcrNumber(UUID orgId);
}
