package com.katasticho.erp.organisation;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface OrgSettingsRepository extends JpaRepository<OrgSetting, UUID> {

    List<OrgSetting> findByOrgId(UUID orgId);

    Optional<OrgSetting> findByOrgIdAndKey(UUID orgId, String key);

    @Modifying
    void deleteByOrgIdAndKey(UUID orgId, String key);

    boolean existsByOrgIdAndKey(UUID orgId, String key);
}
