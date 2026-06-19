package com.katasticho.erp.common.idempotency;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

public interface IdempotencyRecordRepository extends JpaRepository<IdempotencyRecord, UUID> {

    Optional<IdempotencyRecord> findByOrgIdAndIdempotencyKey(UUID orgId, String idempotencyKey);

    @Modifying
    @Transactional
    @Query("DELETE FROM IdempotencyRecord r WHERE r.expiresAt < :cutoff")
    int deleteExpired(Instant cutoff);
}
