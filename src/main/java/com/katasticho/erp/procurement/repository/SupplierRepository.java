package com.katasticho.erp.procurement.repository;

import com.katasticho.erp.procurement.entity.Supplier;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface SupplierRepository extends JpaRepository<Supplier, UUID> {

    Optional<Supplier> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<Supplier> findByOrgIdAndIsDeletedFalseOrderByNameAsc(UUID orgId, Pageable pageable);

    @Query("""
        SELECT s FROM Supplier s
        WHERE s.orgId = :orgId
          AND s.isDeleted = false
          AND (LOWER(s.name) LIKE LOWER(CONCAT('%', :search, '%'))
               OR LOWER(COALESCE(s.gstin, '')) LIKE LOWER(CONCAT('%', :search, '%'))
               OR LOWER(COALESCE(s.phone, '')) LIKE LOWER(CONCAT('%', :search, '%')))
        ORDER BY s.name ASC
    """)
    Page<Supplier> search(UUID orgId, String search, Pageable pageable);

    boolean existsByOrgIdAndGstinAndIsDeletedFalse(UUID orgId, String gstin);
}
