package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.manufacturing.entity.BmrDeviation;
import com.katasticho.erp.manufacturing.entity.BmrSignoff;
import com.katasticho.erp.manufacturing.entity.BmrStepRecord;
import com.katasticho.erp.manufacturing.entity.JobCard;
import com.katasticho.erp.manufacturing.entity.WorkOrder;
import com.katasticho.erp.manufacturing.repository.BmrDeviationRepository;
import com.katasticho.erp.manufacturing.repository.BmrSignoffRepository;
import com.katasticho.erp.manufacturing.repository.BmrStepRecordRepository;
import com.katasticho.erp.manufacturing.repository.JobCardRepository;
import com.katasticho.erp.manufacturing.repository.WorkOrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * Pharma Batch Manufacturing Record (BMR) — Schedule M / WHO-GMP
 * compliance machinery on top of the existing Work Order + Job Card
 * tracking.
 *
 * <p>This service owns three companion entities:
 * <ul>
 *   <li>{@link BmrStepRecord} — in-process parameter readings
 *       (temperature, pH, pressure, time) captured during operations.
 *   <li>{@link BmrSignoff} — operator/supervisor/QA/QC sign-offs at
 *       each critical step + the QA release sign-off at batch close.
 *   <li>{@link BmrDeviation} — exceptions to the master formula, with
 *       severity + investigation + resolution tracking.
 * </ul>
 *
 * <p>Yield reconciliation is read-only from the WO's headline numbers
 * — no separate entity. {@link #yieldReconciliation} returns
 * theoretical (planned) vs actual (produced) qty + deviation %.
 *
 * <p>{@link #bmrSnapshot} bundles everything per work order — the
 * payload a regulator's print-out or PDF generator would consume.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class BmrService {

    private static final Set<String> VALID_ROLES =
            Set.of("OPERATOR", "SUPERVISOR", "QA", "QC");
    private static final Set<String> VALID_SEVERITIES =
            Set.of("MINOR", "MAJOR", "CRITICAL");
    private static final Set<String> VALID_DEVIATION_STATUS =
            Set.of("OPEN", "INVESTIGATING", "RESOLVED", "ACCEPTED");

    private final BmrStepRecordRepository stepRecordRepository;
    private final BmrSignoffRepository signoffRepository;
    private final BmrDeviationRepository deviationRepository;
    private final WorkOrderRepository workOrderRepository;
    private final JobCardRepository jobCardRepository;

    // ── Step records ─────────────────────────────────────────────────

    @Transactional
    public BmrStepRecord recordStepParameter(UUID workOrderId, UUID jobCardId,
                                             String parameterKey, String parameterValue,
                                             String unit, String notes) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        WorkOrder wo = workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(workOrderId, orgId)
                .orElseThrow(() -> BusinessException.notFound("WorkOrder", workOrderId));

        if (parameterKey == null || parameterKey.isBlank()) {
            throw new BusinessException("Parameter key is required",
                    "BMR_PARAM_KEY_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        if (parameterValue == null || parameterValue.isBlank()) {
            throw new BusinessException("Parameter value is required",
                    "BMR_PARAM_VALUE_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        // Validate the job card belongs to the WO (defensive: stops a
        // caller from logging readings against a card on another batch).
        if (jobCardId != null) {
            JobCard jc = jobCardRepository.findByIdAndOrgIdAndIsDeletedFalse(jobCardId, orgId)
                    .orElseThrow(() -> BusinessException.notFound("JobCard", jobCardId));
            if (!jc.getWorkOrderId().equals(wo.getId())) {
                throw new BusinessException(
                        "Job card does not belong to this work order",
                        "BMR_JC_WO_MISMATCH", HttpStatus.BAD_REQUEST);
            }
        }

        BmrStepRecord row = BmrStepRecord.builder()
                .workOrderId(wo.getId())
                .jobCardId(jobCardId)
                .parameterKey(parameterKey.trim())
                .parameterValue(parameterValue.trim())
                .unit(unit)
                .observedAt(Instant.now())
                .observedBy(userId)
                .notes(notes)
                .build();
        row.setOrgId(orgId);
        return stepRecordRepository.save(row);
    }

    @Transactional(readOnly = true)
    public List<BmrStepRecord> listStepRecords(UUID workOrderId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return stepRecordRepository
                .findByOrgIdAndWorkOrderIdAndIsDeletedFalseOrderByObservedAtAsc(orgId, workOrderId);
    }

    // ── Signoffs ─────────────────────────────────────────────────────

    @Transactional
    public BmrSignoff recordSignoff(UUID workOrderId, UUID jobCardId,
                                    String role, String notes) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        if (userId == null) {
            throw new BusinessException(
                    "Cannot record a BMR signoff without an authenticated user",
                    "BMR_SIGNOFF_NO_USER", HttpStatus.UNAUTHORIZED);
        }
        WorkOrder wo = workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(workOrderId, orgId)
                .orElseThrow(() -> BusinessException.notFound("WorkOrder", workOrderId));

        String normalizedRole = role != null ? role.trim().toUpperCase() : "";
        if (!VALID_ROLES.contains(normalizedRole)) {
            throw new BusinessException(
                    "Signoff role must be one of OPERATOR, SUPERVISOR, QA, QC",
                    "BMR_SIGNOFF_INVALID_ROLE", HttpStatus.BAD_REQUEST);
        }
        if (jobCardId != null) {
            JobCard jc = jobCardRepository.findByIdAndOrgIdAndIsDeletedFalse(jobCardId, orgId)
                    .orElseThrow(() -> BusinessException.notFound("JobCard", jobCardId));
            if (!jc.getWorkOrderId().equals(wo.getId())) {
                throw new BusinessException(
                        "Job card does not belong to this work order",
                        "BMR_JC_WO_MISMATCH", HttpStatus.BAD_REQUEST);
            }
        }

        BmrSignoff signoff = BmrSignoff.builder()
                .workOrderId(wo.getId())
                .jobCardId(jobCardId)
                .role(normalizedRole)
                .signedBy(userId)
                .signedAt(Instant.now())
                .notes(notes)
                .build();
        signoff.setOrgId(orgId);
        return signoffRepository.save(signoff);
    }

    @Transactional(readOnly = true)
    public List<BmrSignoff> listSignoffs(UUID workOrderId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return signoffRepository
                .findByOrgIdAndWorkOrderIdAndIsDeletedFalseOrderBySignedAtAsc(orgId, workOrderId);
    }

    // ── Deviations ───────────────────────────────────────────────────

    @Transactional
    public BmrDeviation logDeviation(UUID workOrderId, UUID jobCardId,
                                     String severity, String title, String description) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        WorkOrder wo = workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(workOrderId, orgId)
                .orElseThrow(() -> BusinessException.notFound("WorkOrder", workOrderId));

        String normalizedSeverity = severity != null ? severity.trim().toUpperCase() : "";
        if (!VALID_SEVERITIES.contains(normalizedSeverity)) {
            throw new BusinessException(
                    "Severity must be one of MINOR, MAJOR, CRITICAL",
                    "BMR_DEVIATION_INVALID_SEVERITY", HttpStatus.BAD_REQUEST);
        }
        if (title == null || title.isBlank()) {
            throw new BusinessException("Deviation title is required",
                    "BMR_DEVIATION_TITLE_REQUIRED", HttpStatus.BAD_REQUEST);
        }

        BmrDeviation row = BmrDeviation.builder()
                .workOrderId(wo.getId())
                .jobCardId(jobCardId)
                .severity(normalizedSeverity)
                .title(title.trim())
                .description(description)
                .reportedBy(userId)
                .reportedAt(Instant.now())
                .status("OPEN")
                .build();
        row.setOrgId(orgId);
        return deviationRepository.save(row);
    }

    @Transactional
    public BmrDeviation resolveDeviation(UUID deviationId, String newStatus, String resolution) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        BmrDeviation dev = deviationRepository.findByIdAndOrgIdAndIsDeletedFalse(deviationId, orgId)
                .orElseThrow(() -> BusinessException.notFound("BmrDeviation", deviationId));
        String normalized = newStatus != null ? newStatus.trim().toUpperCase() : "";
        if (!VALID_DEVIATION_STATUS.contains(normalized)) {
            throw new BusinessException(
                    "Status must be one of OPEN, INVESTIGATING, RESOLVED, ACCEPTED",
                    "BMR_DEVIATION_INVALID_STATUS", HttpStatus.BAD_REQUEST);
        }
        dev.setStatus(normalized);
        dev.setResolution(resolution);
        if ("RESOLVED".equals(normalized) || "ACCEPTED".equals(normalized)) {
            dev.setResolvedBy(userId);
            dev.setResolvedAt(Instant.now());
        }
        return deviationRepository.save(dev);
    }

    @Transactional(readOnly = true)
    public List<BmrDeviation> listDeviations(UUID workOrderId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return deviationRepository
                .findByOrgIdAndWorkOrderIdAndIsDeletedFalseOrderByReportedAtAsc(orgId, workOrderId);
    }

    @Transactional(readOnly = true)
    public List<BmrDeviation> listOpenDeviations() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return deviationRepository
                .findByOrgIdAndStatusInAndIsDeletedFalseOrderByReportedAtDesc(
                        orgId, List.of("OPEN", "INVESTIGATING"));
    }

    // ── Yield reconciliation + BMR snapshot ──────────────────────────

    /**
     * Yield reconciliation — theoretical (planned) vs actual (produced)
     * with deviation %. Deviation = (planned − produced) / planned × 100,
     * positive = under-yield, negative = over-yield.
     *
     * <p>Returned shape:
     * <pre>{ plannedQty, producedQty, scrapQty, totalAccountedQty,
     *        yieldPercent, deviationPercent, status }</pre>
     * where {@code status} is {@code "PENDING"} until the WO is
     * COMPLETED, {@code "WITHIN_TOLERANCE"} or {@code "OUT_OF_TOLERANCE"}
     * after. Default tolerance is ±2% — a pharma standard for most solid
     * dosage forms; planners override via org settings later.
     */
    @Transactional(readOnly = true)
    public Map<String, Object> yieldReconciliation(UUID workOrderId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        WorkOrder wo = workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(workOrderId, orgId)
                .orElseThrow(() -> BusinessException.notFound("WorkOrder", workOrderId));

        BigDecimal planned = wo.getQuantityToProduce() != null
                ? wo.getQuantityToProduce() : BigDecimal.ZERO;
        BigDecimal produced = wo.getQuantityProduced() != null
                ? wo.getQuantityProduced() : BigDecimal.ZERO;
        BigDecimal scrap = BigDecimal.ZERO;
        if (wo.getLines() != null) {
            scrap = wo.getLines().stream()
                    .filter(l -> !l.isDeleted())
                    .map(l -> l.getIssuedQty() != null ? l.getIssuedQty() : BigDecimal.ZERO)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            // Note: scrap here is qty issued minus consumed; better to read
            // from production_scrap rows but the WO lines suffice for v1.
        }

        BigDecimal yieldPercent = planned.signum() > 0
                ? produced.multiply(BigDecimal.valueOf(100))
                        .divide(planned, 2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;
        BigDecimal deviationPercent = planned.signum() > 0
                ? planned.subtract(produced)
                        .multiply(BigDecimal.valueOf(100))
                        .divide(planned, 2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;

        String status;
        if (!"COMPLETED".equals(wo.getStatus())) {
            status = "PENDING";
        } else if (deviationPercent.abs().compareTo(BigDecimal.valueOf(2)) <= 0) {
            status = "WITHIN_TOLERANCE";
        } else {
            status = "OUT_OF_TOLERANCE";
        }

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("workOrderId", wo.getId());
        out.put("workOrderNumber", wo.getWorkOrderNumber());
        out.put("status", status);
        out.put("plannedQty", planned);
        out.put("producedQty", produced);
        out.put("scrapQty", scrap);
        out.put("yieldPercent", yieldPercent);
        out.put("deviationPercent", deviationPercent);
        return out;
    }

    /**
     * Bundles the work order, its job cards, all step records, all
     * sign-offs, all deviations, and the yield reconciliation into one
     * payload. This is the document a regulator's printout or PDF
     * generator consumes — every required Schedule M / WHO-GMP section
     * in one read.
     */
    @Transactional(readOnly = true)
    public Map<String, Object> bmrSnapshot(UUID workOrderId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        WorkOrder wo = workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(workOrderId, orgId)
                .orElseThrow(() -> BusinessException.notFound("WorkOrder", workOrderId));

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("workOrder", wo);
        out.put("jobCards", jobCardRepository
                .findByWorkOrderIdAndOrgIdAndIsDeletedFalseOrderBySequenceNumberAsc(
                        wo.getId(), orgId));
        out.put("stepRecords", listStepRecords(wo.getId()));
        out.put("signoffs", listSignoffs(wo.getId()));
        out.put("deviations", listDeviations(wo.getId()));
        out.put("yieldReconciliation", yieldReconciliation(wo.getId()));
        out.put("generatedAt", Instant.now());
        return out;
    }
}
