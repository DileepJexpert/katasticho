package com.katasticho.erp.hr.repository;

import com.katasticho.erp.hr.entity.ShiftAssignment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Repository
public interface ShiftAssignmentRepository extends JpaRepository<ShiftAssignment, UUID> {

    List<ShiftAssignment> findByOrgIdAndUserIdAndIsDeletedFalseOrderByEffectiveFromDesc(
            UUID orgId, UUID userId);

    /** Open-ended (current) assignments for a user. */
    List<ShiftAssignment> findByOrgIdAndUserIdAndEffectiveToIsNullAndIsDeletedFalse(
            UUID orgId, UUID userId);

    /** Assignments that have started on or before a date, newest first. */
    List<ShiftAssignment> findByOrgIdAndUserIdAndEffectiveFromLessThanEqualAndIsDeletedFalseOrderByEffectiveFromDesc(
            UUID orgId, UUID userId, LocalDate date);
}
