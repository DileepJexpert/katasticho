package com.katasticho.erp.common.dto;

import com.katasticho.erp.common.entity.EntityComment;

import java.time.Instant;
import java.util.UUID;

public record EntityCommentResponse(
        UUID id,
        UUID orgId,
        String entityType,
        UUID entityId,
        String commentText,
        boolean system,
        boolean deleted,
        UUID createdBy,
        String createdByName,
        Instant createdAt,
        Instant updatedAt
) {
    public static EntityCommentResponse from(EntityComment c, String authorName) {
        return new EntityCommentResponse(
                c.getId(), c.getOrgId(), c.getEntityType(), c.getEntityId(),
                c.getCommentText(), c.isSystem(), c.isDeleted(),
                c.getCreatedBy(), authorName,
                c.getCreatedAt(), c.getUpdatedAt());
    }
}
