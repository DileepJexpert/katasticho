package com.katasticho.erp.audit.repository;

import com.katasticho.erp.audit.entity.EditLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public interface EditLogRepository extends JpaRepository<EditLog, UUID>, JpaSpecificationExecutor<EditLog> {

    @Query("SELECT e.entityType, e.action, COUNT(e) FROM EditLog e " +
            "WHERE e.orgId = :orgId AND e.changedAt >= :from AND e.changedAt < :to " +
            "GROUP BY e.entityType, e.action")
    List<Object[]> countByTypeAndAction(@Param("orgId") UUID orgId,
                                        @Param("from") Instant from,
                                        @Param("to") Instant to);

    @Query("SELECT e.changedBy, COUNT(e) FROM EditLog e " +
            "WHERE e.orgId = :orgId AND e.changedBy IS NOT NULL " +
            "AND e.changedAt >= :from AND e.changedAt < :to " +
            "GROUP BY e.changedBy ORDER BY COUNT(e) DESC")
    List<Object[]> countByUser(@Param("orgId") UUID orgId,
                               @Param("from") Instant from,
                               @Param("to") Instant to);
}
