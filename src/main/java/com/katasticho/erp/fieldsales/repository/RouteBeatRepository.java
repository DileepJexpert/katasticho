package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.dto.RouteBeatCountProjection;
import com.katasticho.erp.fieldsales.entity.RouteBeat;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

@Repository
public interface RouteBeatRepository extends JpaRepository<RouteBeat, UUID> {

    List<RouteBeat> findByOrgIdAndRouteIdOrderBySequenceNumber(UUID orgId, UUID routeId);

    @Query("""
            select routeBeat.routeId as routeId, count(routeBeat) as beatCount
            from RouteBeat routeBeat
            where routeBeat.orgId = :orgId and routeBeat.routeId in :routeIds
            group by routeBeat.routeId
            """)
    List<RouteBeatCountProjection> countByOrgIdAndRouteIdIn(
            @Param("orgId") UUID orgId,
            @Param("routeIds") Collection<UUID> routeIds);

    void deleteByOrgIdAndRouteId(UUID orgId, UUID routeId);
}
