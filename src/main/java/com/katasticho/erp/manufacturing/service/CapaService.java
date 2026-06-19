package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.manufacturing.entity.CapaAction;
import com.katasticho.erp.manufacturing.entity.NonConformanceReport;
import com.katasticho.erp.manufacturing.repository.CapaActionRepository;
import com.katasticho.erp.manufacturing.repository.NonConformanceReportRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * Tracker #88: CAPA lifecycle.
 *
 * <p>States: {@code OPEN → IN_PROGRESS → COMPLETED → VERIFIED}. Cancel
 * is allowed from any non-terminal state. Each transition is gated by
 * {@code assertStatus()} so the action history stays consistent. The
 * effectiveness review step (COMPLETED → VERIFIED) is the bit that
 * distinguishes CAPA from a generic task list — the verifier checks
 * that the action actually prevented recurrence and signs off.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class CapaService {

    private static final Set<String> VALID_TYPES =
            Set.of("CORRECTIVE", "PREVENTIVE");
    private static final Set<String> VALID_PRIORITIES =
            Set.of("URGENT", "HIGH", "NORMAL", "LOW");

    private final CapaActionRepository capaRepository;
    private final NonConformanceReportRepository ncrRepository;
    private final Clock clock;

    @Transactional
    public CapaAction raise(UUID ncrId, String capaType, String title,
                            String description, String proposedAction,
                            UUID assignedTo, LocalDate dueDate,
                            String priority) {
        UUID orgId = TenantContext.getCurrentOrgId();
        String type = normalise(capaType);
        if (!VALID_TYPES.contains(type)) {
            throw new BusinessException(
                    "capaType must be CORRECTIVE or PREVENTIVE",
                    "CAPA_INVALID_TYPE", HttpStatus.BAD_REQUEST);
        }
        if (title == null || title.isBlank()) {
            throw new BusinessException(
                    "CAPA title is required",
                    "CAPA_TITLE_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        String prio = priority == null ? "NORMAL" : normalise(priority);
        if (!VALID_PRIORITIES.contains(prio)) {
            throw new BusinessException(
                    "priority must be URGENT, HIGH, NORMAL or LOW",
                    "CAPA_INVALID_PRIORITY", HttpStatus.BAD_REQUEST);
        }
        if (ncrId != null) {
            NonConformanceReport ncr = ncrRepository
                    .findByIdAndOrgIdAndIsDeletedFalse(ncrId, orgId)
                    .orElseThrow(() -> BusinessException
                            .notFound("NonConformanceReport", ncrId));
            // Don't allow CAPAs against a CLOSED NCR — close the loop in
            // the right order: CAPAs first, then NCR.
            if ("CLOSED".equals(ncr.getStatus())) {
                throw new BusinessException(
                        "Cannot raise a CAPA against a CLOSED NCR",
                        "CAPA_NCR_CLOSED", HttpStatus.BAD_REQUEST);
            }
        }

        CapaAction capa = CapaAction.builder()
                .capaNumber(nextNumber(orgId))
                .ncrId(ncrId)
                .capaType(type)
                .title(title.trim())
                .description(description)
                .proposedAction(proposedAction)
                .assignedTo(assignedTo)
                .dueDate(dueDate)
                .priority(prio)
                .status("OPEN")
                .build();
        capa.setOrgId(orgId);
        capa = capaRepository.save(capa);
        log.info("CAPA {} raised ({}) for org {}", capa.getCapaNumber(),
                type, orgId);
        return capa;
    }

    @Transactional
    public CapaAction start(UUID id) {
        CapaAction capa = require(id);
        assertStatus(capa, Set.of("OPEN"));
        capa.setStatus("IN_PROGRESS");
        return capaRepository.save(capa);
    }

    @Transactional
    public CapaAction complete(UUID id, String completionNotes) {
        CapaAction capa = require(id);
        assertStatus(capa, Set.of("OPEN", "IN_PROGRESS"));
        capa.setStatus("COMPLETED");
        capa.setCompletionNotes(completionNotes);
        capa.setCompletedAt(Instant.now(clock));
        capa.setCompletedBy(TenantContext.getCurrentUserId());
        return capaRepository.save(capa);
    }

    @Transactional
    public CapaAction verify(UUID id, String effectivenessNotes) {
        CapaAction capa = require(id);
        assertStatus(capa, Set.of("COMPLETED"));
        // Verifier must not be the same person who completed the action
        // — the whole point of the effectiveness review is independent
        // sign-off.
        UUID verifier = TenantContext.getCurrentUserId();
        if (verifier != null && verifier.equals(capa.getCompletedBy())) {
            throw new BusinessException(
                    "Verifier must be different from the completer",
                    "CAPA_SELF_VERIFY_FORBIDDEN", HttpStatus.FORBIDDEN);
        }
        capa.setStatus("VERIFIED");
        capa.setEffectivenessNotes(effectivenessNotes);
        capa.setVerifiedAt(Instant.now(clock));
        capa.setVerifiedBy(verifier);
        return capaRepository.save(capa);
    }

    @Transactional
    public CapaAction cancel(UUID id, String reason) {
        CapaAction capa = require(id);
        if ("VERIFIED".equals(capa.getStatus())
                || "CANCELLED".equals(capa.getStatus())) {
            throw new BusinessException(
                    "Cannot cancel a CAPA in status " + capa.getStatus(),
                    "CAPA_FINAL_STATE", HttpStatus.BAD_REQUEST);
        }
        capa.setStatus("CANCELLED");
        capa.setCompletionNotes(reason);
        capa.setCompletedAt(Instant.now(clock));
        capa.setCompletedBy(TenantContext.getCurrentUserId());
        return capaRepository.save(capa);
    }

    @Transactional(readOnly = true)
    public CapaAction get(UUID id) { return require(id); }

    @Transactional(readOnly = true)
    public Page<CapaAction> list(String status, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (status == null || status.isBlank()) {
            return capaRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(
                    orgId, pageable);
        }
        return capaRepository
                .findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(
                        orgId, normalise(status), pageable);
    }

    @Transactional(readOnly = true)
    public List<CapaAction> listByNcr(UUID ncrId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return capaRepository
                .findByOrgIdAndNcrIdAndIsDeletedFalseOrderByCreatedAtAsc(
                        orgId, ncrId);
    }

    @Transactional(readOnly = true)
    public List<CapaAction> myCapas() {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        if (userId == null) return List.of();
        return capaRepository
                .findByOrgIdAndAssignedToAndIsDeletedFalseOrderByDueDateAsc(
                        orgId, userId);
    }

    @Transactional(readOnly = true)
    public List<CapaAction> overdue() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return capaRepository.findOverdue(orgId,
                LocalDate.now(clock));
    }

    /**
     * Quality-team dashboard rollup: counts per status + overdue count.
     */
    @Transactional(readOnly = true)
    public Map<String, Object> dashboard() {
        UUID orgId = TenantContext.getCurrentOrgId();
        long open = capaRepository
                .findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(
                        orgId, "OPEN", Pageable.unpaged())
                .getTotalElements();
        long inProgress = capaRepository
                .findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(
                        orgId, "IN_PROGRESS", Pageable.unpaged())
                .getTotalElements();
        long completed = capaRepository
                .findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(
                        orgId, "COMPLETED", Pageable.unpaged())
                .getTotalElements();
        long verified = capaRepository
                .findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(
                        orgId, "VERIFIED", Pageable.unpaged())
                .getTotalElements();
        long overdueCount = capaRepository.findOverdue(orgId,
                LocalDate.now(clock)).size();

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("open", open);
        out.put("inProgress", inProgress);
        out.put("completed", completed);
        out.put("verified", verified);
        out.put("overdue", overdueCount);
        return out;
    }

    // ── helpers ─────────────────────────────────────────────────────────

    private CapaAction require(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return capaRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("CapaAction", id));
    }

    private void assertStatus(CapaAction capa, Set<String> allowed) {
        if (!allowed.contains(capa.getStatus())) {
            throw new BusinessException(
                    "CAPA is in status " + capa.getStatus()
                            + "; allowed " + allowed,
                    "CAPA_INVALID_TRANSITION", HttpStatus.BAD_REQUEST);
        }
    }

    private String nextNumber(UUID orgId) {
        int year = LocalDate.now(clock).getYear();
        String prefix = "CAPA-" + year + "-";
        int next = capaRepository.findMaxSequenceForYear(orgId, prefix + "%") + 1;
        return prefix + String.format("%05d", next);
    }

    private String normalise(String s) {
        return s == null ? null : s.trim().toUpperCase();
    }
}
