package com.katasticho.erp.hr.repository;

import com.katasticho.erp.hr.entity.Shift;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ShiftRepository extends JpaRepository<Shift, UUID> {

    Optional<Shift> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Optional<Shift> findByOrgIdAndCodeAndIsDeletedFalse(UUID orgId, String code);

    List<Shift> findByOrgIdAndIsDeletedFalseOrderByNameAsc(UUID orgId);

    List<Shift> findByOrgIdAndActiveTrueAndIsDeletedFalseOrderByNameAsc(UUID orgId);
}
