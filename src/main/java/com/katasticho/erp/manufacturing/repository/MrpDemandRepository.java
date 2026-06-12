package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.MrpDemand;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface MrpDemandRepository extends JpaRepository<MrpDemand, UUID> {

    List<MrpDemand> findByOrgIdAndMrpRunIdAndIsDeletedFalse(UUID orgId, UUID mrpRunId);
}
