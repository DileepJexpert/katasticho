package com.katasticho.erp.franchise.repository;

import com.katasticho.erp.franchise.entity.BranchItemOverride;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface BranchItemOverrideRepository extends JpaRepository<BranchItemOverride, UUID> {

    @Query("SELECT o FROM BranchItemOverride o WHERE o.orgId = :orgId AND o.branchId = :branchId AND o.isDeleted = false")
    List<BranchItemOverride> findByBranchId(@Param("orgId") UUID orgId, @Param("branchId") UUID branchId);

    @Query("SELECT o FROM BranchItemOverride o WHERE o.orgId = :orgId AND o.branchId = :branchId AND o.itemId = :itemId AND o.isDeleted = false")
    Optional<BranchItemOverride> findByBranchAndItem(@Param("orgId") UUID orgId, @Param("branchId") UUID branchId, @Param("itemId") UUID itemId);
}
