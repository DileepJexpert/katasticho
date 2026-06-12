package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.VisitProductLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

@Repository
public interface VisitProductLogRepository extends JpaRepository<VisitProductLog, UUID> {

    List<VisitProductLog> findByOrgIdAndFieldVisitId(UUID orgId, UUID fieldVisitId);

    List<VisitProductLog> findByOrgIdAndFieldVisitIdIn(UUID orgId, Collection<UUID> fieldVisitIds);

    void deleteByOrgIdAndFieldVisitId(UUID orgId, UUID fieldVisitId);
}
