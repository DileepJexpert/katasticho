package com.katasticho.erp.audit;

import com.katasticho.erp.common.context.TenantContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuditService {

    private final AuditLogRepository auditLogRepository;

    @Async
    public void log(String entityType, UUID entityId, String action, String beforeJson, String afterJson) {
        try {
            AuditLog entry = AuditLog.builder()
                    .orgId(TenantContext.getCurrentOrgId())
                    .userId(TenantContext.getCurrentUserId())
                    .entityType(entityType)
                    .entityId(entityId)
                    .action(action)
                    .beforeJson(beforeJson)
                    .afterJson(afterJson)
                    .build();
            auditLogRepository.save(entry);
        } catch (Exception e) {
            // Audit logging should never break the main flow
            log.error("Failed to write audit log for {} {}: {}", entityType, entityId, e.getMessage());
        }
    }

    public void logSync(UUID orgId, UUID userId, String entityType, UUID entityId,
                        String action, String beforeJson, String afterJson) {
        AuditLog entry = AuditLog.builder()
                .orgId(orgId)
                .userId(userId)
                .entityType(entityType)
                .entityId(entityId)
                .action(action)
                .beforeJson(beforeJson)
                .afterJson(afterJson)
                .build();
        auditLogRepository.save(entry);
    }

    public Page<AuditLog> getAuditLogs(UUID orgId, Pageable pageable) {
        return auditLogRepository.findByOrgIdOrderByCreatedAtDesc(orgId, pageable);
    }

    public Page<AuditLog> getAuditLogsByEntityType(UUID orgId, String entityType, Pageable pageable) {
        return auditLogRepository.findByOrgIdAndEntityTypeOrderByCreatedAtDesc(orgId, entityType, pageable);
    }
}
