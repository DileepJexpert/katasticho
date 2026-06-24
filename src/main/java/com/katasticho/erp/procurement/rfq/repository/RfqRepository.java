package com.katasticho.erp.procurement.rfq.repository;

import com.katasticho.erp.procurement.rfq.entity.Rfq;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface RfqRepository extends JpaRepository<Rfq, UUID> {

    Optional<Rfq> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<Rfq> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, Pageable pageable);

    long countByOrgIdAndIsDeletedFalse(UUID orgId);
}
