package com.katasticho.erp.ap.repository;

import com.katasticho.erp.ap.entity.VendorCredit;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface VendorCreditRepository extends JpaRepository<VendorCredit, UUID> {

    Optional<VendorCredit> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<VendorCredit> findByOrgIdAndIsDeletedFalseOrderByCreditDateDesc(UUID orgId, Pageable pageable);

    Page<VendorCredit> findByOrgIdAndContactIdAndIsDeletedFalseOrderByCreditDateDesc(
            UUID orgId, UUID contactId, Pageable pageable);

    List<VendorCredit> findByOrgIdAndContactIdAndStatusAndIsDeletedFalse(
            UUID orgId, UUID contactId, String status);

    Page<VendorCredit> findByOrgIdAndStatusAndIsDeletedFalseOrderByCreditDateDesc(
            UUID orgId, String status, Pageable pageable);
}
