package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.Routing;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface RoutingRepository extends JpaRepository<Routing, UUID> {

    List<Routing> findByOrgIdAndIsDeletedFalseOrderByNameAsc(UUID orgId);

    Optional<Routing> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Optional<Routing> findByOrgIdAndItemIdAndIsDefaultTrueAndIsDeletedFalse(UUID orgId, UUID itemId);
}
