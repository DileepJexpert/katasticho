package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.BomAlternate;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BomAlternateRepository extends JpaRepository<BomAlternate, UUID> {

    Optional<BomAlternate> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<BomAlternate> findByOrgIdAndBomComponentIdAndIsDeletedFalseOrderByPriorityAsc(
            UUID orgId, UUID bomComponentId);

    boolean existsByOrgIdAndBomComponentIdAndAlternateItemIdAndIsDeletedFalse(
            UUID orgId, UUID bomComponentId, UUID alternateItemId);
}
