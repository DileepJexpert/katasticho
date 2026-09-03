package com.katasticho.erp.franchise.repository;

import com.katasticho.erp.franchise.entity.FranchiseNode;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface FranchiseNodeRepository extends JpaRepository<FranchiseNode, UUID> {

    @Query("SELECT n FROM FranchiseNode n WHERE n.orgId = :orgId AND n.isDeleted = false ORDER BY n.nodeCode ASC")
    List<FranchiseNode> findAllByOrgId(@Param("orgId") UUID orgId);

    @Query("SELECT n FROM FranchiseNode n WHERE n.orgId = :orgId AND n.active = true AND n.isDeleted = false")
    List<FranchiseNode> findActiveByOrgId(@Param("orgId") UUID orgId);

    @Query("SELECT n FROM FranchiseNode n WHERE n.orgId = :orgId AND n.nodeCode = :code AND n.isDeleted = false")
    Optional<FranchiseNode> findByOrgIdAndNodeCode(@Param("orgId") UUID orgId, @Param("code") String code);

    @Query("SELECT n FROM FranchiseNode n WHERE n.orgId = :orgId AND n.id = :id AND n.isDeleted = false")
    Optional<FranchiseNode> findByOrgIdAndId(@Param("orgId") UUID orgId, @Param("id") UUID id);
}
