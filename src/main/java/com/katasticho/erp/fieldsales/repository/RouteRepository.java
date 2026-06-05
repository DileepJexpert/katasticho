package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.Route;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface RouteRepository extends JpaRepository<Route, UUID> {

    Optional<Route> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<Route> findByOrgIdAndIsDeletedFalse(UUID orgId, Pageable pageable);

    List<Route> findByOrgIdAndIsActiveTrueAndIsDeletedFalse(UUID orgId);

    List<Route> findByOrgIdAndDayOfWeekAndIsActiveTrueAndIsDeletedFalse(UUID orgId, String dayOfWeek);

    boolean existsByOrgIdAndCodeAndIsDeletedFalse(UUID orgId, String code);
}
