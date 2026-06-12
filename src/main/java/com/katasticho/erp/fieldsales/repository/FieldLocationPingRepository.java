package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.FieldLocationPing;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public interface FieldLocationPingRepository extends JpaRepository<FieldLocationPing, UUID> {

    List<FieldLocationPing> findByOrgIdAndRouteExecutionIdOrderByRecordedAtAsc(UUID orgId, UUID routeExecutionId);

    List<FieldLocationPing> findByOrgIdAndSalespersonIdAndRecordedAtBetweenOrderByRecordedAtAsc(
            UUID orgId, UUID salespersonId, Instant from, Instant to);

    /** Latest ping per salesperson since the given instant. */
    @Query(value = """
            SELECT DISTINCT ON (salesperson_id) *
            FROM field_location_ping
            WHERE org_id = :orgId AND recorded_at >= :since
            ORDER BY salesperson_id, recorded_at DESC
            """, nativeQuery = true)
    List<FieldLocationPing> findLatestPerSalesperson(@Param("orgId") UUID orgId, @Param("since") Instant since);
}
