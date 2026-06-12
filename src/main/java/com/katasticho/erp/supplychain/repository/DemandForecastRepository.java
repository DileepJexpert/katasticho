package com.katasticho.erp.supplychain.repository;

import com.katasticho.erp.supplychain.entity.DemandForecast;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Repository
public interface DemandForecastRepository extends JpaRepository<DemandForecast, UUID> {

    List<DemandForecast> findByOrgIdAndItemIdAndIsDeletedFalseOrderByForecastMonthDesc(UUID orgId, UUID itemId);

    List<DemandForecast> findByOrgIdAndForecastMonthBetweenAndIsDeletedFalseOrderByForecastMonth(
            UUID orgId, LocalDate from, LocalDate to);

    List<DemandForecast> findByOrgIdAndItemIdAndForecastMonthBetweenAndIsDeletedFalseOrderByForecastMonth(
            UUID orgId, UUID itemId, LocalDate from, LocalDate to);
}
