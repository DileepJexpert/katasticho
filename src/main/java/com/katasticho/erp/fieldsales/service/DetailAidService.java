package com.katasticho.erp.fieldsales.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.fieldsales.entity.*;
import com.katasticho.erp.fieldsales.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

/**
 * E-detailing: URL-based detail aids (brochures / visual aids) that field
 * salespeople present during visits, plus the per-visit log of what was
 * shown. Vertical-neutral — pharma product brochures, FMCG promo decks,
 * distributor catalogs all fit. Media lives at a URL the org hosts.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class DetailAidService {

    private static final Set<String> MEDIA_TYPES = Set.of("PDF", "IMAGE", "VIDEO", "LINK");

    private final DetailAidRepository detailAidRepository;
    private final VisitDetailAidLogRepository logRepository;
    private final FieldVisitRepository fieldVisitRepository;
    private final RouteExecutionRepository routeExecutionRepository;

    // ── Aid management (OWNER/ADMIN) ─────────────────────────────────────

    @Transactional
    public DetailAid create(String name, String description, String mediaUrl,
                            String mediaType, String productName) {
        validate(name, mediaUrl);
        return detailAidRepository.save(DetailAid.builder()
                .orgId(TenantContext.getCurrentOrgId())
                .name(name.trim())
                .description(description)
                .mediaUrl(mediaUrl.trim())
                .mediaType(normalizeType(mediaType))
                .productName(productName)
                .createdBy(TenantContext.getCurrentUserId())
                .build());
    }

    @Transactional
    public DetailAid update(UUID id, String name, String description, String mediaUrl,
                            String mediaType, String productName, Boolean active) {
        DetailAid aid = load(id);
        validate(name, mediaUrl);
        aid.setName(name.trim());
        aid.setDescription(description);
        aid.setMediaUrl(mediaUrl.trim());
        aid.setMediaType(normalizeType(mediaType));
        aid.setProductName(productName);
        if (active != null) aid.setActive(active);
        return detailAidRepository.save(aid);
    }

    @Transactional
    public void delete(UUID id) {
        DetailAid aid = load(id);
        aid.setDeleted(true);
        detailAidRepository.save(aid);
    }

    /** All aids with usage counts — the management view. */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> listWithUsage() {
        UUID orgId = TenantContext.getCurrentOrgId();
        Map<UUID, Long> usage = new HashMap<>();
        for (Object[] row : logRepository.countShownByAid(orgId)) {
            usage.put((UUID) row[0], ((Number) row[1]).longValue());
        }
        List<Map<String, Object>> result = new ArrayList<>();
        for (DetailAid aid : detailAidRepository.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId)) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("id", aid.getId());
            row.put("name", aid.getName());
            row.put("description", aid.getDescription());
            row.put("mediaUrl", aid.getMediaUrl());
            row.put("mediaType", aid.getMediaType());
            row.put("productName", aid.getProductName());
            row.put("active", aid.isActive());
            row.put("timesShown", usage.getOrDefault(aid.getId(), 0L));
            result.add(row);
        }
        return result;
    }

    /** Active aids only — what the field app offers during a visit. */
    @Transactional(readOnly = true)
    public List<DetailAid> activeAids() {
        return detailAidRepository
                .findByOrgIdAndIsActiveTrueAndIsDeletedFalseOrderByNameAsc(
                        TenantContext.getCurrentOrgId());
    }

    // ── Per-visit log (assigned salesperson) ─────────────────────────────

    /** Replaces the visit's shown-aids log. Post-check-in, owner-only. */
    @Transactional
    public List<VisitDetailAidLog> logShown(UUID visitId, List<UUID> aidIds) {
        UUID orgId = TenantContext.getCurrentOrgId();
        FieldVisit visit = fieldVisitRepository.findByIdAndOrgIdAndIsDeletedFalse(visitId, orgId)
                .orElseThrow(() -> BusinessException.notFound("FieldVisit", visitId));
        ensureVisitOwnership(visit, orgId);
        if ("PLANNED".equals(visit.getStatus()) || "SKIPPED".equals(visit.getStatus())) {
            throw new BusinessException(
                    "Detail aids can only be logged after check-in, visit status: " + visit.getStatus(),
                    "MR_VISIT_NOT_STARTED", HttpStatus.BAD_REQUEST);
        }

        logRepository.deleteByOrgIdAndFieldVisitId(orgId, visitId);

        List<VisitDetailAidLog> rows = new ArrayList<>();
        for (UUID aidId : aidIds != null ? aidIds : List.<UUID>of()) {
            DetailAid aid = load(aidId);   // validates org ownership of the aid
            rows.add(VisitDetailAidLog.builder()
                    .orgId(orgId)
                    .fieldVisitId(visitId)
                    .detailAidId(aid.getId())
                    .build());
        }
        return logRepository.saveAll(rows);
    }

    @Transactional(readOnly = true)
    public List<VisitDetailAidLog> visitLog(UUID visitId) {
        return logRepository.findByOrgIdAndFieldVisitId(TenantContext.getCurrentOrgId(), visitId);
    }

    // ── helpers ──────────────────────────────────────────────────────────

    private DetailAid load(UUID id) {
        return detailAidRepository.findByIdAndOrgIdAndIsDeletedFalse(id, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("DetailAid", id));
    }

    private void validate(String name, String mediaUrl) {
        if (name == null || name.isBlank()) {
            throw new BusinessException("Name is required", "DA_NAME_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        if (mediaUrl == null || mediaUrl.isBlank()
                || !(mediaUrl.startsWith("http://") || mediaUrl.startsWith("https://"))) {
            throw new BusinessException("A valid http(s) media URL is required",
                    "DA_URL_INVALID", HttpStatus.BAD_REQUEST);
        }
    }

    private String normalizeType(String type) {
        String t = type != null ? type.toUpperCase(Locale.ROOT) : "LINK";
        return MEDIA_TYPES.contains(t) ? t : "LINK";
    }

    private void ensureVisitOwnership(FieldVisit visit, UUID orgId) {
        RouteExecution execution = routeExecutionRepository
                .findByIdAndOrgIdAndIsDeletedFalse(visit.getRouteExecutionId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("RouteExecution", visit.getRouteExecutionId()));
        if (!execution.getSalespersonId().equals(TenantContext.getCurrentUserId())) {
            throw new BusinessException(
                    "Only the assigned salesperson can perform this visit action",
                    "FS_NOT_ASSIGNED_SALESPERSON", HttpStatus.FORBIDDEN);
        }
    }
}
