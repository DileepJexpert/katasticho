package com.katasticho.erp.common.repository;

import com.katasticho.erp.common.entity.Notification;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.UUID;

public interface NotificationRepository extends JpaRepository<Notification, UUID> {

    Page<Notification> findByOrgIdAndUserIdOrderByCreatedAtDesc(
            UUID orgId, UUID userId, Pageable pageable);

    long countByOrgIdAndUserIdAndReadFalse(UUID orgId, UUID userId);

    boolean existsByOrgIdAndTypeAndEntityIdAndCreatedAtAfter(
            UUID orgId, String type, UUID entityId, Instant after);

    @Modifying
    @Query("UPDATE Notification n SET n.read = true, n.readAt = CURRENT_TIMESTAMP " +
           "WHERE n.orgId = :orgId AND n.userId = :userId AND n.read = false")
    void markAllReadForUser(@Param("orgId") UUID orgId, @Param("userId") UUID userId);
}
