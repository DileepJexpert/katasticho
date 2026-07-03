package com.katasticho.erp.payroll.india;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface IndiaGratuityAccrualRepository extends JpaRepository<IndiaGratuityAccrual, UUID> {

    Optional<IndiaGratuityAccrual> findByOrgIdAndPeriodYearAndPeriodMonthAndIsDeletedFalse(
            UUID orgId, int periodYear, int periodMonth);
}
