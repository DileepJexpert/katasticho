package com.katasticho.erp.payroll.repository;

import com.katasticho.erp.payroll.entity.PayrollRun;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PayrollRunRepository extends JpaRepository<PayrollRun, UUID> {

    Optional<PayrollRun> findByIdAndOrgId(UUID id, UUID orgId);

    /** Pessimistic-write re-read so concurrent approve/post serialise (no double-book). */
    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT pr FROM PayrollRun pr WHERE pr.id = :id AND pr.orgId = :orgId")
    Optional<PayrollRun> findByIdAndOrgIdForUpdate(UUID id, UUID orgId);

    Page<PayrollRun> findByOrgIdOrderByPeriodStartDesc(UUID orgId, Pageable pageable);

    /**
     * Check for overlapping non-cancelled payroll periods.
     */
    @Query("SELECT pr FROM PayrollRun pr WHERE pr.orgId = :orgId " +
            "AND pr.status NOT IN ('CANCELLED') " +
            "AND ((pr.periodStart <= :end AND pr.periodEnd >= :start))")
    List<PayrollRun> findOverlapping(UUID orgId, LocalDate start, LocalDate end);

    /** Runs of a given status whose period starts within [from, to] — salary-TDS by quarter/FY. */
    List<PayrollRun> findByOrgIdAndStatusAndPeriodStartBetweenOrderByPeriodStart(
            UUID orgId, String status, LocalDate from, LocalDate to);
}
