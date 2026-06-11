package com.katasticho.erp.integration.repository;

import com.katasticho.erp.integration.entity.IntegrationSyncLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface IntegrationSyncLogRepository extends JpaRepository<IntegrationSyncLog, UUID> {

    List<IntegrationSyncLog> findByOrgIdAndIntegrationIdAndIsDeletedFalseOrderByStartedAtDesc(
            UUID orgId, UUID integrationId);

    List<IntegrationSyncLog> findByOrgIdAndIsDeletedFalseOrderByStartedAtDesc(UUID orgId);
}
