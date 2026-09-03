package com.katasticho.erp.franchise.repository;

import com.katasticho.erp.franchise.entity.FranchiseCatalogPolicy;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface FranchiseCatalogPolicyRepository extends JpaRepository<FranchiseCatalogPolicy, UUID> {

    @Query("SELECT p FROM FranchiseCatalogPolicy p WHERE p.orgId = :orgId AND p.isDeleted = false")
    Optional<FranchiseCatalogPolicy> findByOrgId(@Param("orgId") UUID orgId);
}
