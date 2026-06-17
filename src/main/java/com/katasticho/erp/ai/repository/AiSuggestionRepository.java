package com.katasticho.erp.ai.repository;

import com.katasticho.erp.ai.entity.AiSuggestion;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface AiSuggestionRepository extends JpaRepository<AiSuggestion, UUID> {

    Optional<AiSuggestion> findByIdAndOrgId(UUID id, UUID orgId);

    /** The current open suggestion for an entity of a given type — for escalate-or-create. */
    Optional<AiSuggestion> findFirstByOrgIdAndEntityTypeAndEntityIdAndSuggestionTypeAndStatusInOrderByCreatedAtDesc(
            UUID orgId, String entityType, UUID entityId, String suggestionType, Collection<String> statuses);

    Page<AiSuggestion> findByOrgIdOrderByPriorityScoreDescCreatedAtDesc(UUID orgId, Pageable pageable);

    Page<AiSuggestion> findByOrgIdAndStatusOrderByPriorityScoreDescCreatedAtDesc(
            UUID orgId, String status, Pageable pageable);

    long countByOrgIdAndStatus(UUID orgId, String status);

    @Query("""
        SELECT COUNT(s) > 0 FROM AiSuggestion s
        WHERE s.orgId = :orgId
          AND s.entityType = :entityType
          AND s.entityId = :entityId
          AND (:entityLineId IS NULL OR s.entityLineId = :entityLineId)
          AND s.suggestionType = :suggestionType
          AND s.status IN :statuses
    """)
    boolean existsOpenSuggestion(UUID orgId, String entityType, UUID entityId, UUID entityLineId,
                                 String suggestionType, Collection<String> statuses);

    /** Delete un-actioned (PENDING) suggestions for entities being replaced —
     *  prevents duplicate inbox items when a generator re-runs (e.g. GSTR-2B
     *  re-upload). Already-reviewed (ACCEPTED/REJECTED) rows are preserved. */
    @Modifying
    @Query("""
        DELETE FROM AiSuggestion s
        WHERE s.orgId = :orgId
          AND s.entityType = :entityType
          AND s.entityId IN :entityIds
          AND s.status = 'PENDING'
    """)
    int deletePendingByEntityIds(UUID orgId, String entityType, Collection<UUID> entityIds);

    @Query("""
        SELECT COUNT(s) FROM AiSuggestion s
        WHERE s.orgId = :orgId
          AND s.status = 'PENDING'
          AND s.priority IN ('HIGH', 'CRITICAL')
    """)
    long countHighPriorityPending(UUID orgId);

    List<AiSuggestion> findByOrgIdAndSuggestionTypeInOrderByPriorityScoreDescCreatedAtDesc(
            UUID orgId, Collection<String> suggestionTypes);

    List<AiSuggestion> findByOrgIdAndSuggestionTypeInAndStatusOrderByPriorityScoreDescCreatedAtDesc(
            UUID orgId, Collection<String> suggestionTypes, String status);

    List<AiSuggestion> findByOrgIdInOrderByPriorityScoreDescCreatedAtDesc(Collection<UUID> orgIds);

    List<AiSuggestion> findByOrgIdInAndStatusOrderByPriorityScoreDescCreatedAtDesc(Collection<UUID> orgIds, String status);

    long countByOrgIdAndStatusAndPriorityAndCreatedAtBefore(UUID orgId, String status, String priority, Instant before);
}
