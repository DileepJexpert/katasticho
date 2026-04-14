package com.katasticho.erp.common.repository;

import com.katasticho.erp.common.entity.EntityComment;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface EntityCommentRepository extends JpaRepository<EntityComment, UUID> {

    Page<EntityComment> findByOrgIdAndEntityTypeAndEntityIdAndDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, String entityType, UUID entityId, Pageable pageable);

    Optional<EntityComment> findByIdAndOrgId(UUID id, UUID orgId);
}
