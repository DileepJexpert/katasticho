package com.katasticho.erp.amortization.repository;

import com.katasticho.erp.amortization.entity.AmortizationSchedule;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface AmortizationScheduleRepository extends JpaRepository<AmortizationSchedule, UUID> {

    Optional<AmortizationSchedule> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<AmortizationSchedule> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId);

    List<AmortizationSchedule> findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtAsc(
            UUID orgId, String status);
}
