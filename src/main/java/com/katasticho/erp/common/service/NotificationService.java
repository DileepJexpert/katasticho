package com.katasticho.erp.common.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.entity.Notification;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.repository.NotificationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository notificationRepository;

    @Transactional
    public void notify(UUID orgId, UUID userId, String title, String message,
                       String severity, String entityType, UUID entityId) {
        notificationRepository.save(Notification.builder()
                .orgId(orgId)
                .userId(userId)
                .title(title)
                .message(message)
                .severity(severity != null ? severity : "INFO")
                .entityType(entityType)
                .entityId(entityId)
                .channel("IN_APP")
                .build());
    }

    @Transactional(readOnly = true)
    public Page<Notification> listForUser(Pageable pageable) {
        UUID orgId  = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        return notificationRepository.findByOrgIdAndUserIdOrderByCreatedAtDesc(orgId, userId, pageable);
    }

    @Transactional(readOnly = true)
    public long countUnread() {
        UUID orgId  = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        return notificationRepository.countByOrgIdAndUserIdAndReadFalse(orgId, userId);
    }

    @Transactional
    public void markRead(UUID notificationId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Notification n = notificationRepository.findById(notificationId)
                .filter(x -> x.getOrgId().equals(orgId))
                .orElseThrow(() -> BusinessException.notFound("Notification", notificationId));
        n.setRead(true);
        notificationRepository.save(n);
    }

    @Transactional
    public void markAllRead() {
        UUID orgId  = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        notificationRepository.markAllReadForUser(orgId, userId);
    }
}
