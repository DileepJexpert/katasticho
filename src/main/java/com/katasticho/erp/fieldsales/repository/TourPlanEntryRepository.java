package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.TourPlanEntry;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface TourPlanEntryRepository extends JpaRepository<TourPlanEntry, UUID> {

    List<TourPlanEntry> findByOrgIdAndTourPlanIdOrderByPlanDate(UUID orgId, UUID tourPlanId);

    Optional<TourPlanEntry> findByIdAndOrgId(UUID id, UUID orgId);

    void deleteByOrgIdAndTourPlanId(UUID orgId, UUID tourPlanId);
}
