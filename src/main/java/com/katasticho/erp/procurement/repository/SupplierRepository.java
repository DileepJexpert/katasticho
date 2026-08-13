package com.katasticho.erp.procurement.repository;

import com.katasticho.erp.procurement.entity.Supplier;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.Collection;
import java.util.List;
import java.util.UUID;

@Repository
public interface SupplierRepository extends JpaRepository<Supplier, UUID> {

    Optional<Supplier> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<Supplier> findByOrgIdAndIsDeletedFalseOrderByNameAsc(UUID orgId, Pageable pageable);

    /**
     * Supplier projections that are safe for purchase flows. A supplier must
     * be active, linked to a live Contact, and retain the Vendor/Both role.
     * This keeps legacy standalone projections out of PO/GRN/Bill pickers.
     */
    @Query("""
        SELECT s FROM Supplier s
        JOIN Contact c ON c.id = s.contactId
        WHERE s.orgId = :orgId
          AND s.isDeleted = false
          AND s.active = true
          AND c.orgId = :orgId
          AND c.isDeleted = false
          AND c.contactType IN ('VENDOR', 'BOTH')
        ORDER BY s.name ASC
    """)
    Page<Supplier> findSelectable(UUID orgId, Pageable pageable);

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

    @Query("""
        SELECT s FROM Supplier s
        JOIN Contact c ON c.id = s.contactId
        WHERE s.orgId = :orgId
          AND s.isDeleted = false
          AND s.active = true
          AND c.orgId = :orgId
          AND c.isDeleted = false
          AND c.contactType IN ('VENDOR', 'BOTH')
          AND (LOWER(s.name) LIKE LOWER(CONCAT('%', :search, '%'))
               OR LOWER(COALESCE(s.gstin, '')) LIKE LOWER(CONCAT('%', :search, '%'))
               OR LOWER(COALESCE(s.phone, '')) LIKE LOWER(CONCAT('%', :search, '%'))
               OR LOWER(COALESCE(s.city, '')) LIKE LOWER(CONCAT('%', :search, '%')))
        ORDER BY s.name ASC
    """)
    Page<Supplier> searchSelectable(UUID orgId, String search, Pageable pageable);

    boolean existsByOrgIdAndGstinAndIsDeletedFalse(UUID orgId, String gstin);

    Optional<Supplier> findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(UUID orgId, String name);

    Optional<Supplier> findFirstByOrgIdAndContactIdAndIsDeletedFalse(UUID orgId, UUID contactId);

    boolean existsByOrgIdAndContactIdAndActiveTrueAndIsDeletedFalse(UUID orgId, UUID contactId);

    List<Supplier> findByOrgIdAndContactIdInAndActiveTrueAndIsDeletedFalse(
            UUID orgId, Collection<UUID> contactIds);
}
