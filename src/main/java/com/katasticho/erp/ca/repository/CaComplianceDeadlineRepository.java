package com.katasticho.erp.ca.repository;

import com.katasticho.erp.ca.entity.CaComplianceDeadline;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface CaComplianceDeadlineRepository extends JpaRepository<CaComplianceDeadline, UUID> {

    Optional<CaComplianceDeadline> findByIdAndClientOrgIdIn(UUID id, Collection<UUID> clientOrgIds);

    List<CaComplianceDeadline> findByClientOrgIdInAndDueDateBetweenOrderByDueDateAsc(
            Collection<UUID> clientOrgIds, LocalDate from, LocalDate to);

    List<CaComplianceDeadline> findTop3ByClientOrgIdAndStatusOrderByDueDateAsc(UUID clientOrgId, String status);

    long countByClientOrgIdInAndStatusAndDueDateBetween(Collection<UUID> clientOrgIds, String status,
                                                        LocalDate from, LocalDate to);

    long countByClientOrgIdAndStatusAndDueDateBefore(UUID clientOrgId, String status, LocalDate date);

    long countByClientOrgIdAndStatusAndDueDateBetween(UUID clientOrgId, String status, LocalDate from, LocalDate to);

    boolean existsByCaClientLinkIdAndDeadlineTypeAndPeriodLabel(UUID caClientLinkId, String deadlineType,
                                                                String periodLabel);

    @Query("""
        SELECT d FROM CaComplianceDeadline d
        WHERE d.clientOrgId IN :clientOrgIds
          AND (:status IS NULL OR d.status = :status)
          AND (:deadlineType IS NULL OR d.deadlineType = :deadlineType)
          AND (:clientOrgId IS NULL OR d.clientOrgId = :clientOrgId)
          AND d.dueDate BETWEEN :fromDate AND :toDate
        ORDER BY d.dueDate ASC
    """)
    List<CaComplianceDeadline> search(Collection<UUID> clientOrgIds, String status, String deadlineType,
                                      UUID clientOrgId, LocalDate fromDate, LocalDate toDate);
}
