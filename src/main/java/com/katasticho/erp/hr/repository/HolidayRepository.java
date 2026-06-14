package com.katasticho.erp.hr.repository;

import com.katasticho.erp.hr.entity.Holiday;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface HolidayRepository extends JpaRepository<Holiday, UUID> {

    Optional<Holiday> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<Holiday> findByOrgIdAndHolidayDateBetweenAndIsDeletedFalseOrderByHolidayDateAsc(
            UUID orgId, LocalDate from, LocalDate to);

    boolean existsByOrgIdAndHolidayDateAndIsDeletedFalse(UUID orgId, LocalDate holidayDate);
}
