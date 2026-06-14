package com.katasticho.erp.hr.repository;

import com.katasticho.erp.hr.entity.HrTicket;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface HrTicketRepository extends JpaRepository<HrTicket, UUID> {

    Optional<HrTicket> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<HrTicket> findByOrgIdAndRaisedByUserIdAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, UUID raisedByUserId);

    List<HrTicket> findByOrgIdAndAssignedToUserIdAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, UUID assignedToUserId);

    List<HrTicket> findByOrgIdAndStatusInAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, List<String> statuses);
}
