package com.katasticho.erp.audit;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface AuditLogRepository extends JpaRepository<AuditLog, UUID> {

    Page<AuditLog> findByOrgIdOrderByCreatedAtDesc(UUID orgId, Pageable pageable);

    Page<AuditLog> findByOrgIdAndEntityTypeOrderByCreatedAtDesc(UUID orgId, String entityType, Pageable pageable);
}
