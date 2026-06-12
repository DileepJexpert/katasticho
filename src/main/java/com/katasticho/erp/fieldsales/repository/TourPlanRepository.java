package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.TourPlan;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface TourPlanRepository extends JpaRepository<TourPlan, UUID> {

    Optional<TourPlan> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Optional<TourPlan> findByOrgIdAndSalespersonIdAndPlanMonthAndIsDeletedFalse(
            UUID orgId, UUID salespersonId, LocalDate planMonth);

    List<TourPlan> findByOrgIdAndSalespersonIdAndIsDeletedFalseOrderByPlanMonthDesc(
            UUID orgId, UUID salespersonId);

    List<TourPlan> findByOrgIdAndStatusAndIsDeletedFalseOrderByPlanMonthDesc(
            UUID orgId, String status);
}
