package com.katasticho.erp.pharma.repository;

import com.katasticho.erp.pharma.entity.CustomerIndent;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CustomerIndentRepository extends JpaRepository<CustomerIndent, UUID> {

    Page<CustomerIndent> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, Pageable pageable);

    Page<CustomerIndent> findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, String status, Pageable pageable);

    Optional<CustomerIndent> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    @Query("""
            SELECT i FROM CustomerIndent i
            WHERE i.orgId = :orgId
              AND i.itemId = :itemId
              AND i.isDeleted = false
              AND i.status IN :statuses
            ORDER BY i.createdAt ASC
            """)
    List<CustomerIndent> findOpenForItem(
            @Param("orgId") UUID orgId,
            @Param("itemId") UUID itemId,
            @Param("statuses") List<String> statuses);

    long countByOrgIdAndIsDeletedFalse(UUID orgId);
}
