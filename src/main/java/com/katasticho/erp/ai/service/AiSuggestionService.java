package com.katasticho.erp.ai.service;

import com.katasticho.erp.ai.dto.AiInboxSummaryResponse;
import com.katasticho.erp.ai.dto.AiSuggestionResponse;
import com.katasticho.erp.ai.dto.AiSuggestionReviewRequest;
import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.entity.AiTrainingExample;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.ai.repository.AiTrainingExampleRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.PagedResponse;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Collection;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AiSuggestionService {

    private static final Set<String> REVIEW_ACTIONS = Set.of("ACCEPT", "REJECT", "MODIFY", "DEFER");

    private final AiSuggestionRepository aiSuggestionRepository;
    private final AiTrainingExampleRepository aiTrainingExampleRepository;

    @Transactional(readOnly = true)
    public PagedResponse<AiSuggestionResponse> list(String status, Pageable pageable) {
        UUID orgId = requireOrgId();
        var page = (status == null || status.isBlank())
                ? aiSuggestionRepository.findByOrgIdOrderByPriorityScoreDescCreatedAtDesc(orgId, pageable)
                : aiSuggestionRepository.findByOrgIdAndStatusOrderByPriorityScoreDescCreatedAtDesc(
                        orgId, normalizeStatus(status), pageable);
        return PagedResponse.from(page.map(AiSuggestionResponse::from));
    }

    @Transactional(readOnly = true)
    public AiSuggestionResponse get(UUID id) {
        return AiSuggestionResponse.from(getForCurrentOrg(id));
    }

    @Transactional(readOnly = true)
    public AiInboxSummaryResponse summary() {
        UUID orgId = requireOrgId();
        return new AiInboxSummaryResponse(
                aiSuggestionRepository.countByOrgIdAndStatus(orgId, "PENDING"),
                aiSuggestionRepository.countHighPriorityPending(orgId)
        );
    }

    private static final Set<String> REVIEWABLE_STATUSES = Set.of("PENDING", "DEFERRED");

    @Transactional
    public AiSuggestionResponse review(UUID id, AiSuggestionReviewRequest request) {
        String action = normalizeAction(request.action());
        AiSuggestion suggestion = getForCurrentOrg(id);

        if (!REVIEWABLE_STATUSES.contains(suggestion.getStatus())) {
            throw new BusinessException(
                    "Suggestion already resolved with status: " + suggestion.getStatus(),
                    "AI_SUGGESTION_ALREADY_RESOLVED"
            );
        }

        UUID userId = TenantContext.getCurrentUserId();
        Instant now = Instant.now();

        suggestion.setStatus(statusForAction(action));
        suggestion.setReviewAction(action);
        suggestion.setReviewedBy(userId);
        suggestion.setReviewedAt(now);
        suggestion.setReviewedValue(request.reviewedValue());
        suggestion.setCorrectionReason(request.correctionReason());

        AiSuggestion saved = aiSuggestionRepository.save(suggestion);

        if (!"DEFER".equals(action)) {
            createTrainingExample(saved, action, userId);
        }

        return AiSuggestionResponse.from(saved);
    }

    public AiSuggestion createSuggestion(AiSuggestion suggestion) {
        if (suggestion.getOrgId() == null) {
            suggestion.setOrgId(requireOrgId());
        }
        return aiSuggestionRepository.save(suggestion);
    }

    /**
     * Remove un-actioned (PENDING) suggestions tied to entities that are about
     * to be replaced, so re-running a generator (e.g. GSTR-2B re-upload) doesn't
     * accumulate duplicate inbox items. Reviewed rows are preserved.
     */
    @Transactional
    public int dismissPendingForEntities(String entityType, Collection<UUID> entityIds) {
        if (entityIds == null || entityIds.isEmpty()) return 0;
        return aiSuggestionRepository.deletePendingByEntityIds(
                requireOrgId(), entityType, entityIds);
    }

    private void createTrainingExample(AiSuggestion suggestion, String action, UUID userId) {
        Map<String, Object> humanOutput = suggestion.getReviewedValue() != null
                ? suggestion.getReviewedValue()
                : Map.of("action", action);

        AiTrainingExample example = AiTrainingExample.builder()
                .orgId(suggestion.getOrgId())
                .sourceSuggestionId(suggestion.getId())
                .entityType(suggestion.getEntityType())
                .entityId(suggestion.getEntityId())
                .taskType(suggestion.getSuggestionType())
                .inputSnapshot(Map.of(
                        "entityType", suggestion.getEntityType(),
                        "entityId", suggestion.getEntityId().toString(),
                        "suggestionType", suggestion.getSuggestionType()
                ))
                .aiOutput(suggestion.getSuggestedValue())
                .humanOutput(humanOutput)
                .correctionType(action)
                .correctionReason(suggestion.getCorrectionReason())
                .createdBy(userId)
                .build();
        aiTrainingExampleRepository.save(example);
    }

    private AiSuggestion getForCurrentOrg(UUID id) {
        UUID orgId = requireOrgId();
        return aiSuggestionRepository.findByIdAndOrgId(id, orgId)
                .orElseThrow(() -> new BusinessException(
                        "AI suggestion not found",
                        "AI_SUGGESTION_NOT_FOUND",
                        HttpStatus.NOT_FOUND
                ));
    }

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }

    private String normalizeStatus(String status) {
        return status.trim().toUpperCase();
    }

    private String normalizeAction(String action) {
        String normalized = action.trim().toUpperCase();
        if (!REVIEW_ACTIONS.contains(normalized)) {
            throw new BusinessException(
                    "Review action must be ACCEPT, REJECT, MODIFY, or DEFER",
                    "AI_INVALID_REVIEW_ACTION"
            );
        }
        return normalized;
    }

    private String statusForAction(String action) {
        return switch (action) {
            case "ACCEPT" -> "ACCEPTED";
            case "REJECT" -> "REJECTED";
            case "MODIFY" -> "MODIFIED";
            case "DEFER" -> "DEFERRED";
            default -> throw new IllegalArgumentException("Unexpected action: " + action);
        };
    }
}
