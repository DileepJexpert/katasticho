package com.katasticho.erp.common.repository;

import com.katasticho.erp.common.entity.OrgFeatureFlag;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface OrgFeatureFlagRepository extends JpaRepository<OrgFeatureFlag, UUID> {

    List<OrgFeatureFlag> findByOrgId(UUID orgId);

    Optional<OrgFeatureFlag> findByOrgIdAndFeature(UUID orgId, String feature);

    List<OrgFeatureFlag> findByOrgIdAndEnabledTrue(UUID orgId);

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("delete from OrgFeatureFlag f where f.orgId = :orgId")
    void deleteByOrgId(@Param("orgId") UUID orgId);
}
