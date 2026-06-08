package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.QcTemplate;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface QcTemplateRepository extends JpaRepository<QcTemplate, UUID> {

    List<QcTemplate> findByOrgIdAndIsDeletedFalseOrderByNameAsc(UUID orgId);

    Optional<QcTemplate> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<QcTemplate> findByOrgIdAndItemIdAndInspectionTypeAndIsActiveTrueAndIsDeletedFalse(
            UUID orgId, UUID itemId, String inspectionType);
}
