package com.katasticho.erp.hr.repository;

import com.katasticho.erp.hr.entity.TimesheetEntry;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface TimesheetEntryRepository extends JpaRepository<TimesheetEntry, UUID> {

    Optional<TimesheetEntry> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<TimesheetEntry> findByOrgIdAndUserIdAndWorkDateBetweenAndIsDeletedFalseOrderByWorkDateDesc(
            UUID orgId, UUID userId, LocalDate from, LocalDate to);

    List<TimesheetEntry> findByOrgIdAndUserIdAndStatusAndWorkDateBetweenAndIsDeletedFalse(
            UUID orgId, UUID userId, String status, LocalDate from, LocalDate to);

    List<TimesheetEntry> findByOrgIdAndStatusAndIsDeletedFalseOrderByWorkDateDesc(
            UUID orgId, String status);
}
