package com.katasticho.erp.audit.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.audit.entity.EditLog;
import com.katasticho.erp.audit.repository.EditLogRepository;
import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.context.TenantContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Read API over the append-only {@code edit_log} audit trail. Query-only by
 * design — there is deliberately no write/update/delete path here.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class EditLogService {

    private final EditLogRepository editLogRepository;
    private final AppUserRepository appUserRepository;
    private final ObjectMapper objectMapper;

    public record EditLogEntryResponse(UUID id, String entityType, UUID entityId, String action,
                                       String entityLabel, Map<String, Object> fieldChanges,
                                       UUID changedBy, String changedByName, Instant changedAt) {
    }

    @Transactional(readOnly = true)
    public Page<EditLogEntryResponse> list(String entityType, UUID entityId, String action,
                                           UUID userId, LocalDate from, LocalDate to,
                                           Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Specification<EditLog> spec = (root, query, cb) -> cb.equal(root.get("orgId"), orgId);
        if (entityType != null && !entityType.isBlank()) {
            String normalized = entityType.trim().toUpperCase(Locale.ROOT);
            spec = spec.and((root, query, cb) -> cb.equal(root.get("entityType"), normalized));
        }
        if (entityId != null) {
            spec = spec.and((root, query, cb) -> cb.equal(root.get("entityId"), entityId));
        }
        if (action != null && !action.isBlank()) {
            String normalized = action.trim().toUpperCase(Locale.ROOT);
            spec = spec.and((root, query, cb) -> cb.equal(root.get("action"), normalized));
        }
        if (userId != null) {
            spec = spec.and((root, query, cb) -> cb.equal(root.get("changedBy"), userId));
        }
        if (from != null) {
            Instant fromInstant = from.atStartOfDay(ZoneOffset.UTC).toInstant();
            spec = spec.and((root, query, cb) ->
                    cb.greaterThanOrEqualTo(root.get("changedAt"), fromInstant));
        }
        if (to != null) {
            Instant toExclusive = to.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant();
            spec = spec.and((root, query, cb) -> cb.lessThan(root.get("changedAt"), toExclusive));
        }

        Page<EditLog> page = editLogRepository.findAll(spec, pageable);
        Map<UUID, String> userNames = resolveUserNames(page.getContent().stream()
                .map(EditLog::getChangedBy)
                .filter(java.util.Objects::nonNull)
                .collect(Collectors.toSet()));
        return page.map(entry -> toResponse(entry, userNames));
    }

    /** Rollup for the audit dashboard: totals + per-action + per-type + top editors. */
    @Transactional(readOnly = true)
    public Map<String, Object> summary(LocalDate from, LocalDate to) {
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate effectiveTo = to != null ? to : LocalDate.now(ZoneOffset.UTC);
        LocalDate effectiveFrom = from != null ? from : effectiveTo.minusDays(29);
        Instant fromInstant = effectiveFrom.atStartOfDay(ZoneOffset.UTC).toInstant();
        Instant toExclusive = effectiveTo.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant();

        long total = 0;
        Map<String, Long> byAction = new LinkedHashMap<>();
        Map<String, Long> byEntityType = new LinkedHashMap<>();
        for (Object[] row : editLogRepository.countByTypeAndAction(orgId, fromInstant, toExclusive)) {
            String type = (String) row[0];
            String rowAction = (String) row[1];
            long count = ((Number) row[2]).longValue();
            total += count;
            byAction.merge(rowAction, count, Long::sum);
            byEntityType.merge(type, count, Long::sum);
        }

        List<Object[]> userCounts = editLogRepository.countByUser(orgId, fromInstant, toExclusive);
        Map<UUID, String> userNames = resolveUserNames(userCounts.stream()
                .map(row -> (UUID) row[0])
                .collect(Collectors.toSet()));
        List<Map<String, Object>> topUsers = new ArrayList<>();
        for (Object[] row : userCounts) {
            if (topUsers.size() >= 10) {
                break;
            }
            UUID changedBy = (UUID) row[0];
            Map<String, Object> user = new HashMap<>();
            user.put("userId", changedBy);
            user.put("name", userNames.get(changedBy));
            user.put("count", ((Number) row[1]).longValue());
            topUsers.add(user);
        }

        Map<String, Object> summary = new LinkedHashMap<>();
        summary.put("from", effectiveFrom);
        summary.put("to", effectiveTo);
        summary.put("totalChanges", total);
        summary.put("byAction", byAction);
        summary.put("byEntityType", byEntityType);
        summary.put("topUsers", topUsers);
        return summary;
    }

    private Map<UUID, String> resolveUserNames(Set<UUID> userIds) {
        if (userIds.isEmpty()) {
            return Map.of();
        }
        return appUserRepository.findAllById(userIds).stream()
                .collect(Collectors.toMap(AppUser::getId, Function.identity()))
                .entrySet().stream()
                .collect(Collectors.toMap(Map.Entry::getKey, e -> e.getValue().getFullName()));
    }

    private EditLogEntryResponse toResponse(EditLog entry, Map<UUID, String> userNames) {
        Map<String, Object> changes = null;
        if (entry.getFieldChanges() != null) {
            try {
                changes = objectMapper.readValue(entry.getFieldChanges(),
                        new TypeReference<Map<String, Object>>() {
                        });
            } catch (Exception e) {
                log.warn("edit-log: unparseable field_changes on {}: {}",
                        entry.getId(), e.getMessage());
            }
        }
        return new EditLogEntryResponse(
                entry.getId(),
                entry.getEntityType(),
                entry.getEntityId(),
                entry.getAction(),
                entry.getEntityLabel(),
                changes,
                entry.getChangedBy(),
                entry.getChangedBy() != null ? userNames.get(entry.getChangedBy()) : null,
                entry.getChangedAt());
    }
}
