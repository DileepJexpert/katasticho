package com.katasticho.erp.accounting.repository;

import com.katasticho.erp.accounting.entity.FiscalPeriod;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface FiscalPeriodRepository extends JpaRepository<FiscalPeriod, UUID> {

    Optional<FiscalPeriod> findByOrgIdAndPeriodYearAndPeriodMonth(UUID orgId, int periodYear, int periodMonth);

    List<FiscalPeriod> findByOrgIdOrderByPeriodYearDescPeriodMonthDesc(UUID orgId);
}
