package com.katasticho.erp.indent.repository;

import com.katasticho.erp.indent.entity.CustomerIndent;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

@Repository
public interface CustomerIndentRepository extends JpaRepository<CustomerIndent, UUID> {

    Page<CustomerIndent> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, Pageable pageable);

    Page<CustomerIndent> findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, String status, Pageable pageable);

    List<CustomerIndent> findByOrgIdAndItemIdAndStatusInAndIsDeletedFalse(UUID orgId, UUID itemId, Collection<String> statuses);

    long countByOrgIdAndStatusAndIsDeletedFalse(UUID orgId, String status);
}
