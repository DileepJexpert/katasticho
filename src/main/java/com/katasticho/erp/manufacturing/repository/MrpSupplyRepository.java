package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.MrpSupply;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface MrpSupplyRepository extends JpaRepository<MrpSupply, UUID> {

    List<MrpSupply> findByOrgIdAndMrpRunIdAndIsDeletedFalse(UUID orgId, UUID mrpRunId);
}
