package com.katasticho.erp.supplychain.repository;

import com.katasticho.erp.supplychain.entity.SupplierPerformance;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface SupplierPerformanceRepository extends JpaRepository<SupplierPerformance, UUID> {

    List<SupplierPerformance> findByOrgIdAndSupplierIdAndIsDeletedFalseOrderByPeriodStartDesc(UUID orgId, UUID supplierId);

    Optional<SupplierPerformance> findByOrgIdAndSupplierIdAndPeriodStartAndPeriodEndAndIsDeletedFalse(
            UUID orgId, UUID supplierId, LocalDate periodStart, LocalDate periodEnd);

    List<SupplierPerformance> findByOrgIdAndIsDeletedFalseOrderByOverallScoreDesc(UUID orgId);
}
