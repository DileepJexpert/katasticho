package com.katasticho.erp.dunning.repository;

import com.katasticho.erp.dunning.entity.DunningLevel;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface DunningLevelRepository extends JpaRepository<DunningLevel, UUID> {

    Optional<DunningLevel> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<DunningLevel> findByOrgIdAndIsDeletedFalseOrderBySeqAsc(UUID orgId);

    List<DunningLevel> findByOrgIdAndActiveTrueAndIsDeletedFalseOrderBySeqAsc(UUID orgId);
}
