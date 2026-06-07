package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.ScrapReasonCode;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ScrapReasonCodeRepository extends JpaRepository<ScrapReasonCode, UUID> {

    List<ScrapReasonCode> findByOrgIdAndIsActiveTrueAndIsDeletedFalseOrderByCodeAsc(UUID orgId);

    Optional<ScrapReasonCode> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);
}
