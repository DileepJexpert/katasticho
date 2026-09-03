package com.katasticho.erp.franchise.repository;

import com.katasticho.erp.franchise.entity.FranchiseRoyaltySettlement;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface FranchiseRoyaltySettlementRepository extends JpaRepository<FranchiseRoyaltySettlement, UUID> {

    @Query("SELECT s FROM FranchiseRoyaltySettlement s WHERE s.orgId = :orgId AND s.isDeleted = false ORDER BY s.periodStart DESC")
    List<FranchiseRoyaltySettlement> findAllByOrgId(@Param("orgId") UUID orgId);

    @Query("SELECT s FROM FranchiseRoyaltySettlement s WHERE s.orgId = :orgId AND s.franchiseNodeId = :nodeId AND s.isDeleted = false ORDER BY s.periodStart DESC")
    List<FranchiseRoyaltySettlement> findByNodeId(@Param("orgId") UUID orgId, @Param("nodeId") UUID nodeId);

    @Query("SELECT s FROM FranchiseRoyaltySettlement s WHERE s.orgId = :orgId AND s.id = :id AND s.isDeleted = false")
    Optional<FranchiseRoyaltySettlement> findByOrgIdAndId(@Param("orgId") UUID orgId, @Param("id") UUID id);
}
