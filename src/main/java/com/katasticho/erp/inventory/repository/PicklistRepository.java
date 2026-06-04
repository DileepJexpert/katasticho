package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.Picklist;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PicklistRepository extends JpaRepository<Picklist, UUID> {

    Optional<Picklist> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<Picklist> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, Pageable pageable);

    List<Picklist> findBySalesOrderIdAndIsDeletedFalse(UUID salesOrderId);

    @Query("SELECT COALESCE(MAX(CAST(SUBSTRING(p.picklistNumber, LENGTH(:prefix) + 2) AS int)), 0) + 1 " +
            "FROM Picklist p WHERE p.orgId = :orgId AND p.picklistNumber LIKE CONCAT(:prefix, '-%')")
    int nextSequence(UUID orgId, String prefix);
}
