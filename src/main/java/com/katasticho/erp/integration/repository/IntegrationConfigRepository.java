package com.katasticho.erp.integration.repository;

import com.katasticho.erp.integration.entity.IntegrationConfig;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface IntegrationConfigRepository extends JpaRepository<IntegrationConfig, UUID> {

    List<IntegrationConfig> findByOrgIdAndIsActiveTrueAndIsDeletedFalse(UUID orgId);

    List<IntegrationConfig> findByOrgIdAndIsDeletedFalse(UUID orgId);
}
