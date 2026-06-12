package com.katasticho.erp.notification.push;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PushTokenRepository extends JpaRepository<PushToken, UUID> {

    /** All active tokens for a specific user in this org. */
    List<PushToken> findByOrgIdAndUserIdAndIsDeletedFalse(UUID orgId, UUID userId);

    /** All active tokens in the org (for broadcast notifications). */
    List<PushToken> findByOrgIdAndIsActiveTrueAndIsDeletedFalse(UUID orgId);

    /** Look up a specific device token (for upsert / deregister). */
    Optional<PushToken> findByOrgIdAndDeviceTokenAndIsDeletedFalse(UUID orgId, String deviceToken);
}
