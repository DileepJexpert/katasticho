package com.katasticho.erp.contact.repository;

import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import jakarta.persistence.LockModeType;

public interface ContactRepository extends JpaRepository<Contact, UUID> {

    Page<Contact> findByOrgIdAndIsDeletedFalse(UUID orgId, Pageable pageable);

    long countByOrgIdAndIsDeletedFalse(UUID orgId);

    Page<Contact> findByOrgIdAndContactTypeAndIsDeletedFalse(
            UUID orgId, ContactType type, Pageable pageable);

    List<Contact> findByOrgIdAndContactTypeInAndIsDeletedFalse(
            UUID orgId, Collection<ContactType> types);

    @Query("""
            SELECT c FROM Contact c
            WHERE c.orgId = :orgId
              AND c.isDeleted = false
              AND (LOWER(c.displayName) LIKE LOWER(CONCAT('%', :q, '%'))
                OR LOWER(c.companyName) LIKE LOWER(CONCAT('%', :q, '%'))
                OR LOWER(c.email)       LIKE LOWER(CONCAT('%', :q, '%'))
                OR c.phone              LIKE CONCAT('%', :q, '%')
                OR c.mobile             LIKE CONCAT('%', :q, '%')
                OR LOWER(c.gstin)       LIKE LOWER(CONCAT('%', :q, '%'))
                OR LOWER(c.taxId)       LIKE LOWER(CONCAT('%', :q, '%')))
            """)
    Page<Contact> search(@Param("orgId") UUID orgId, @Param("q") String query, Pageable pageable);

    @Query("""
            SELECT c FROM Contact c
            WHERE c.orgId = :orgId
              AND c.isDeleted = false
              AND (:search IS NULL OR :search = ''
                OR LOWER(c.displayName) LIKE LOWER(CONCAT('%', :search, '%'))
                OR LOWER(c.companyName) LIKE LOWER(CONCAT('%', :search, '%'))
                OR LOWER(c.email)       LIKE LOWER(CONCAT('%', :search, '%'))
                OR c.phone              LIKE CONCAT('%', :search, '%')
                OR c.mobile             LIKE CONCAT('%', :search, '%')
                OR LOWER(c.gstin)       LIKE LOWER(CONCAT('%', :search, '%'))
                OR LOWER(c.taxId)       LIKE LOWER(CONCAT('%', :search, '%')))
              AND (c.contactType = :type OR c.contactType = 'BOTH')
            ORDER BY c.displayName ASC
            """)
    Page<Contact> findByRoleAndSearch(
            @Param("orgId") UUID orgId,
            @Param("type") ContactType type,
            @Param("search") String search,
            Pageable pageable);

    @Query("""
            SELECT c FROM Contact c
            WHERE c.orgId = :orgId
              AND c.isDeleted = false
              AND (:search IS NULL OR :search = ''
                OR LOWER(c.displayName) LIKE LOWER(CONCAT('%', :search, '%'))
                OR LOWER(c.companyName) LIKE LOWER(CONCAT('%', :search, '%'))
                OR LOWER(c.email)       LIKE LOWER(CONCAT('%', :search, '%'))
                OR c.phone              LIKE CONCAT('%', :search, '%')
                OR c.mobile             LIKE CONCAT('%', :search, '%')
                OR LOWER(c.gstin)       LIKE LOWER(CONCAT('%', :search, '%'))
                OR LOWER(c.taxId)       LIKE LOWER(CONCAT('%', :search, '%')))
              AND EXISTS (
                  SELECT s.id FROM Supplier s
                  WHERE s.orgId = :orgId
                    AND s.contactId = c.id
                    AND s.isDeleted = false
                    AND s.active = true
              )
            ORDER BY c.displayName ASC
            """)
    Page<Contact> findSupplierContacts(
            @Param("orgId") UUID orgId,
            @Param("search") String search,
            Pageable pageable);

    @Query("""
            SELECT COUNT(c) FROM Contact c
            WHERE c.orgId = :orgId AND c.isDeleted = false
              AND (c.contactType = 'CUSTOMER' OR c.contactType = 'BOTH')
            """)
    long countCustomers(@Param("orgId") UUID orgId);

    @Query("""
            SELECT COUNT(c) FROM Contact c
            WHERE c.orgId = :orgId AND c.isDeleted = false
              AND (c.contactType = 'VENDOR' OR c.contactType = 'BOTH')
            """)
    long countVendors(@Param("orgId") UUID orgId);

    @Query("""
            SELECT COUNT(c) FROM Contact c
            WHERE c.orgId = :orgId
              AND c.isDeleted = false
              AND EXISTS (
                  SELECT s.id FROM Supplier s
                  WHERE s.orgId = :orgId
                    AND s.contactId = c.id
                    AND s.isDeleted = false
                    AND s.active = true
              )
            """)
    long countSupplierContacts(@Param("orgId") UUID orgId);

    @Query("""
            SELECT c FROM Contact c
            WHERE c.orgId = :orgId
              AND c.isDeleted = false
              AND (c.contactType = 'CUSTOMER' OR c.contactType = 'BOTH')
            """)
    Page<Contact> findCustomers(@Param("orgId") UUID orgId, Pageable pageable);

    @Query("""
            SELECT c FROM Contact c
            WHERE c.orgId = :orgId
              AND c.isDeleted = false
              AND (c.contactType = 'VENDOR' OR c.contactType = 'BOTH')
            """)
    Page<Contact> findVendors(@Param("orgId") UUID orgId, Pageable pageable);

    Optional<Contact> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    /** Serializes concurrent role-enablement requests for the same party. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
            SELECT c FROM Contact c
            WHERE c.id = :id AND c.orgId = :orgId AND c.isDeleted = false
            """)
    Optional<Contact> findForSupplierRole(@Param("id") UUID id, @Param("orgId") UUID orgId);

    List<Contact> findByOrgIdAndIsDeletedFalseAndIdIn(UUID orgId, Collection<UUID> ids);

    /** MSME-registered contacts — MSME Form 1 filters vendors from these. */
    List<Contact> findByOrgIdAndMsmeRegisteredTrueAndIsDeletedFalse(UUID orgId);

    @Query("""
            SELECT c FROM Contact c
            WHERE c.orgId = :orgId
              AND c.isDeleted = false
              AND (c.contactType = 'CUSTOMER' OR c.contactType = 'BOTH')
              AND c.salesHold = true
              AND (c.salesHoldUntil IS NULL OR c.salesHoldUntil >= :today)
            """)
    List<Contact> findActiveCustomerSalesHolds(@Param("orgId") UUID orgId, @Param("today") java.time.LocalDate today);

    boolean existsByOrgIdAndGstinAndIsDeletedFalse(UUID orgId, String gstin);

    boolean existsByOrgIdAndGstinAndIdNotAndIsDeletedFalse(UUID orgId, String gstin, UUID id);

    /** Resolve a contact by GSTIN — used by AI bill drafting to match a scanned
     * vendor to an existing contact (any type) before creating a new one. */
    Optional<Contact> findFirstByOrgIdAndGstinIgnoreCaseAndIsDeletedFalse(UUID orgId, String gstin);

    /** Resolve a contact by exact display name (case-insensitive) when the
     * scanned bill has no GSTIN to match on. */
    Optional<Contact> findFirstByOrgIdAndDisplayNameIgnoreCaseAndIsDeletedFalse(UUID orgId, String displayName);

    java.util.List<Contact> findByOrgIdAndVisitsPerMonthGreaterThanAndIsDeletedFalse(UUID orgId, Integer minVisits);

    /** Customers pinned to a specific price list (contact.defaultPriceListId). */
    List<Contact> findByOrgIdAndDefaultPriceListIdAndIsDeletedFalse(UUID orgId, UUID priceListId);
}
