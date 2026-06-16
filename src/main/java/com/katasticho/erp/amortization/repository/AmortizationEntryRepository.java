package com.katasticho.erp.amortization.repository;

import com.katasticho.erp.amortization.entity.AmortizationEntry;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface AmortizationEntryRepository extends JpaRepository<AmortizationEntry, UUID> {

    boolean existsByOrgIdAndScheduleIdAndPeriodYearAndPeriodMonth(
            UUID orgId, UUID scheduleId, int periodYear, int periodMonth);

    List<AmortizationEntry> findByOrgIdAndScheduleIdOrderByPeriodYearAscPeriodMonthAsc(
            UUID orgId, UUID scheduleId);
}
