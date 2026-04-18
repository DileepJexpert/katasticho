package com.katasticho.erp.common.repository;

import com.katasticho.erp.common.dto.EntityCommentResponse;
import com.katasticho.erp.common.entity.EntityComment;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface EntityCommentRepository extends JpaRepository<EntityComment, UUID> {

    Page<EntityComment> findByOrgIdAndEntityTypeAndEntityIdAndDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, String entityType, UUID entityId, Pageable pageable);

    Optional<EntityComment> findByIdAndOrgId(UUID id, UUID orgId);

    /**
     * Timeline query: joins with AppUser to surface the author's display name
     * alongside each comment, so clients don't need a second round-trip to
     * render "Added by Rajesh Kumar".
     */
    @Query("""
           SELECT new com.katasticho.erp.common.dto.EntityCommentResponse(
               c.id, c.orgId, c.entityType, c.entityId, c.commentText,
               c.system, c.deleted, c.createdBy, u.fullName,
               c.createdAt, c.updatedAt)
           FROM EntityComment c
           LEFT JOIN com.katasticho.erp.auth.entity.AppUser u ON u.id = c.createdBy
           WHERE c.orgId = :orgId
             AND c.entityType = :entityType
             AND c.entityId = :entityId
             AND c.deleted = false
           ORDER BY c.createdAt DESC
           """)
    Page<EntityCommentResponse> findTimeline(
            @Param("orgId") UUID orgId,
            @Param("entityType") String entityType,
            @Param("entityId") UUID entityId,
            Pageable pageable);
}
