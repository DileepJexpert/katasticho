package com.katasticho.erp.ar.repository;

import com.katasticho.erp.ar.entity.ReminderLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ReminderLogRepository extends JpaRepository<ReminderLog, UUID> {

    @Query("""
        SELECT r FROM ReminderLog r
        WHERE r.orgId = :orgId AND r.contactId = :contactId
        ORDER BY r.sentAt DESC
        LIMIT 1
    """)
    Optional<ReminderLog> findLatestByOrgAndContact(UUID orgId, UUID contactId);

    @Query("""
        SELECT r FROM ReminderLog r
        WHERE r.orgId = :orgId
          AND r.contactId = :contactId
          AND r.followupStatus IS NOT NULL
        ORDER BY r.sentAt DESC
        LIMIT 1
    """)
    Optional<ReminderLog> findLatestFollowUpByOrgAndContact(UUID orgId, UUID contactId);

    @Query("""
        SELECT r FROM ReminderLog r
        WHERE r.orgId = :orgId
          AND r.contactId = :contactId
          AND r.followupStatus IS NOT NULL
        ORDER BY r.sentAt DESC
    """)
    List<ReminderLog> findFollowUpsByOrgAndContact(UUID orgId, UUID contactId);

    @Query("""
        SELECT r.contactId AS contactId, MAX(r.sentAt) AS lastSentAt
        FROM ReminderLog r
        WHERE r.orgId = :orgId AND r.contactId IN :contactIds
        GROUP BY r.contactId
    """)
    List<ContactLastReminder> findLastRemindersByContacts(UUID orgId, List<UUID> contactIds);

    @Query("""
        SELECT r FROM ReminderLog r
        WHERE r.orgId = :orgId
          AND r.contactId IN :contactIds
          AND r.followupStatus IS NOT NULL
          AND r.sentAt = (
              SELECT MAX(r2.sentAt) FROM ReminderLog r2
              WHERE r2.orgId = r.orgId
                AND r2.contactId = r.contactId
                AND r2.followupStatus IS NOT NULL
          )
    """)
    List<ReminderLog> findLatestFollowUpsByContacts(UUID orgId, List<UUID> contactIds);

    interface ContactLastReminder {
        UUID getContactId();
        Instant getLastSentAt();
    }
}
