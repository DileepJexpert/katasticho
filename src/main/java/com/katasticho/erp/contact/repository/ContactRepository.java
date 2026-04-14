package com.katasticho.erp.contact.repository;

import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface ContactRepository extends JpaRepository<Contact, UUID> {

    Page<Contact> findByOrgIdAndIsDeletedFalse(UUID orgId, Pageable pageable);

    Page<Contact> findByOrgIdAndContactTypeAndIsDeletedFalse(
            UUID orgId, ContactType type, Pageable pageable);

    @Query("""
            SELECT c FROM Contact c
            WHERE c.orgId = :orgId
              AND c.isDeleted = false
              AND (LOWER(c.displayName) LIKE LOWER(CONCAT('%', :q, '%'))
                OR LOWER(c.companyName) LIKE LOWER(CONCAT('%', :q, '%'))
                OR LOWER(c.email)       LIKE LOWER(CONCAT('%', :q, '%'))
                OR c.phone              LIKE CONCAT('%', :q, '%'))
            """)
    Page<Contact> search(@Param("orgId") UUID orgId, @Param("q") String query, Pageable pageable);

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

    boolean existsByOrgIdAndGstinAndIsDeletedFalse(UUID orgId, String gstin);

    boolean existsByOrgIdAndGstinAndIdNotAndIsDeletedFalse(UUID orgId, String gstin, UUID id);
}
