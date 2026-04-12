package com.katasticho.erp.audit;

import com.katasticho.erp.common.context.TenantContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.ObjectProvider;
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
    /**
     * Self-injected via {@link ObjectProvider} so calls to {@link #doLogAsync} go
     * through the Spring proxy — without this, self-invocation would bypass the
     * {@code @Async} advice and the audit insert would run on the request thread.
     */
    private final ObjectProvider<AuditService> selfProvider;

    /**
     * Public entry point. Captures the tenant context on the **caller thread**
     * (the request thread) before crossing the {@code @Async} boundary, because
     * {@link TenantContext} is a {@link ThreadLocal} and is not propagated to the
     * async executor pool.
     */
    public void log(String entityType, UUID entityId, String action, String beforeJson, String afterJson) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        if (orgId == null) {
            log.warn("Skipping audit log for {} {} — no tenant context on caller thread",
                    entityType, entityId);
            return;
        }
        selfProvider.getObject().doLogAsync(orgId, userId, entityType, entityId, action, beforeJson, afterJson);
    }

    @Async
    public void doLogAsync(UUID orgId, UUID userId, String entityType, UUID entityId,
                           String action, String beforeJson, String afterJson) {
        try {
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
