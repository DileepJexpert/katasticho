package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.VisitDetailAidLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface VisitDetailAidLogRepository extends JpaRepository<VisitDetailAidLog, UUID> {

    List<VisitDetailAidLog> findByOrgIdAndFieldVisitId(UUID orgId, UUID fieldVisitId);

    void deleteByOrgIdAndFieldVisitId(UUID orgId, UUID fieldVisitId);

    /** Times each aid has been shown — usage stats for the management screen. */
    @Query("""
            SELECT l.detailAidId, COUNT(l)
            FROM VisitDetailAidLog l
            WHERE l.orgId = :orgId
            GROUP BY l.detailAidId
            """)
    List<Object[]> countShownByAid(@Param("orgId") UUID orgId);
}
