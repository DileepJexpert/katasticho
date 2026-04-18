package com.katasticho.erp.common.service;

import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.EntityCommentResponse;
import com.katasticho.erp.common.entity.EntityComment;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.repository.EntityCommentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class CommentService {

    private final EntityCommentRepository commentRepository;
    private final AppUserRepository appUserRepository;

    @Transactional
    public EntityCommentResponse addComment(String entityType, UUID entityId, String text) {
        UUID orgId  = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        EntityComment comment = EntityComment.builder()
                .orgId(orgId)
                .entityType(entityType)
                .entityId(entityId)
                .commentText(text)
                .system(false)
                .createdBy(userId)
                .build();
        comment = commentRepository.save(comment);
        return EntityCommentResponse.from(comment, resolveAuthorName(userId));
    }

    /** Called internally by services when status changes — not deletable by users. */
    @Transactional
    public EntityComment addSystemComment(String entityType, UUID entityId, String text) {
        return addSystemComment(TenantContext.getCurrentOrgId(), entityType, entityId, text);
    }

    /**
     * Overload for scheduled jobs and other contexts where {@link TenantContext}
     * is not populated — the caller already knows which org it's operating on.
     */
    @Transactional
    public EntityComment addSystemComment(UUID orgId, String entityType, UUID entityId, String text) {
        EntityComment comment = EntityComment.builder()
                .orgId(orgId)
                .entityType(entityType)
                .entityId(entityId)
                .commentText(text)
                .system(true)
                .build();
        return commentRepository.save(comment);
    }

    @Transactional(readOnly = true)
    public Page<EntityCommentResponse> listComments(String entityType, UUID entityId, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return commentRepository.findTimeline(orgId, entityType, entityId, pageable);
    }

    @Transactional
    public void deleteComment(UUID commentId) {
        UUID orgId  = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        EntityComment comment = commentRepository.findByIdAndOrgId(commentId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Comment", commentId));
        if (comment.isSystem()) {
            throw new BusinessException("System comments cannot be deleted",
                    "COMMENT_SYSTEM_DELETE", HttpStatus.FORBIDDEN);
        }
        if (!userId.equals(comment.getCreatedBy())) {
            throw new BusinessException("You can only delete your own comments",
                    "COMMENT_NOT_OWNER", HttpStatus.FORBIDDEN);
        }
        comment.setDeleted(true);
        commentRepository.save(comment);
    }

    private String resolveAuthorName(UUID userId) {
        if (userId == null) return null;
        return appUserRepository.findById(userId).map(u -> u.getFullName()).orElse(null);
    }
}
