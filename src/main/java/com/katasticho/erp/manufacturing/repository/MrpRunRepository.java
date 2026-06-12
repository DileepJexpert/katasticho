package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.MrpRun;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface MrpRunRepository extends JpaRepository<MrpRun, UUID> {

    Optional<MrpRun> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<MrpRun> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId);
}
