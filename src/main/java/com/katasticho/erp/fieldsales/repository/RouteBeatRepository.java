package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.RouteBeat;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface RouteBeatRepository extends JpaRepository<RouteBeat, UUID> {

    List<RouteBeat> findByOrgIdAndRouteIdOrderBySequenceNumber(UUID orgId, UUID routeId);

    void deleteByOrgIdAndRouteId(UUID orgId, UUID routeId);
}
