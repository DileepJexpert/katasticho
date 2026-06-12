package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.ReferenceType;
import com.katasticho.erp.inventory.entity.WarehouseZone;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import com.katasticho.erp.inventory.repository.WarehouseZoneRepository;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.manufacturing.entity.*;
import com.katasticho.erp.manufacturing.repository.*;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class QualityControlService {

    private static final Set<String> FINALIZED_STATUSES = Set.of("PASSED", "FAILED", "PARTIAL");

    private final QcTemplateRepository templateRepository;
    private final QcParameterRepository parameterRepository;
    private final QcInspectionRepository inspectionRepository;
    private final QcInspectionResultRepository resultRepository;
    private final NonConformanceReportRepository ncrRepository;
    private final InventoryService inventoryService;
    private final WorkOrderRepository workOrderRepository;
    private final WarehouseZoneRepository warehouseZoneRepository;
    private final ItemRepository itemRepository;
    private final StockBatchRepository stockBatchRepository;
    private final OrganisationRepository organisationRepository;

    // ── Templates ─────────────────────────────────────────────────

    @Transactional
    public QcTemplate createTemplate(String name, UUID itemId, String inspectionType,
                                      List<QcParameterInput> parameters) {
        UUID orgId = TenantContext.getCurrentOrgId();

        QcTemplate template = QcTemplate.builder()
                .name(name)
                .itemId(itemId)
                .inspectionType(inspectionType != null ? inspectionType : "INCOMING")
                .parameters(new ArrayList<>())
                .build();
        template = templateRepository.save(template);

        if (parameters != null) {
            for (int i = 0; i < parameters.size(); i++) {
                QcParameterInput p = parameters.get(i);
                QcParameter param = QcParameter.builder()
                        .template(template)
                        .name(p.name())
                        .description(p.description())
                        .parameterType(p.parameterType() != null ? p.parameterType() : "NUMERIC")
                        .unit(p.unit())
                        .minValue(p.minValue())
                        .maxValue(p.maxValue())
                        .acceptableValues(p.acceptableValues())
                        .isMandatory(p.isMandatory() != null ? p.isMandatory() : true)
                        .sequenceNumber(i + 1)
                        .build();
                template.getParameters().add(param);
            }
            template = templateRepository.save(template);
        }

        log.info("Created QC template '{}' ({}) with {} parameters for org {}",
                name, inspectionType, template.getParameters().size(), orgId);
        return template;
    }

    @Transactional(readOnly = true)
    public List<QcTemplate> listTemplates() {
        return templateRepository.findByOrgIdAndIsDeletedFalseOrderByNameAsc(
                TenantContext.getCurrentOrgId());
    }

    @Transactional(readOnly = true)
    public QcTemplate getTemplate(UUID id) {
        return templateRepository.findByIdAndOrgIdAndIsDeletedFalse(id, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("QcTemplate", id));
    }

    // ── Inspections ───────────────────────────────────────────────

    @Transactional
    public QcInspection createInspection(UUID templateId, String inspectionType,
                                          String referenceType, UUID referenceId,
                                          UUID itemId, UUID batchId,
                                          BigDecimal inspectedQty) {
        UUID orgId = TenantContext.getCurrentOrgId();

        int nextNum = (int) inspectionRepository.count() + 1;
        String inspNumber = String.format("QC-%05d", nextNum);

        QcInspection inspection = QcInspection.builder()
                .inspectionNumber(inspNumber)
                .templateId(templateId)
                .inspectionType(inspectionType != null ? inspectionType : "INCOMING")
                .referenceType(referenceType)
                .referenceId(referenceId)
                .itemId(itemId)
                .batchId(batchId)
                .inspectedQty(inspectedQty)
                .results(new ArrayList<>())
                .build();

        inspection = inspectionRepository.save(inspection);
        log.info("Created QC inspection {} ({}) for item {} org {}",
                inspNumber, inspectionType, itemId, orgId);
        return inspection;
    }

    @Transactional(readOnly = true)
    public Page<QcInspection> listInspections(Pageable pageable) {
        return inspectionRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(
                TenantContext.getCurrentOrgId(), pageable);
    }

    @Transactional(readOnly = true)
    public QcInspection getInspection(UUID id) {
        return inspectionRepository.findByIdAndOrgIdAndIsDeletedFalse(id, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("QcInspection", id));
    }

    @Transactional
    public QcInspection recordResults(UUID inspectionId, List<QcResultInput> results) {
        UUID orgId = TenantContext.getCurrentOrgId();

        QcInspection inspection = inspectionRepository.findByIdAndOrgIdAndIsDeletedFalse(inspectionId, orgId)
                .orElseThrow(() -> BusinessException.notFound("QcInspection", inspectionId));

        if ("PASSED".equals(inspection.getStatus()) || "FAILED".equals(inspection.getStatus())) {
            throw new BusinessException("Inspection is already finalized: " + inspection.getStatus(),
                    "QC_ALREADY_FINALIZED", HttpStatus.BAD_REQUEST);
        }

        for (QcResultInput input : results) {
            QcInspectionResult result = QcInspectionResult.builder()
                    .inspection(inspection)
                    .parameterId(input.parameterId())
                    .measuredValue(input.measuredValue())
                    .numericValue(input.numericValue())
                    .isPassed(input.isPassed())
                    .notes(input.notes())
                    .build();
            inspection.getResults().add(result);
        }

        inspection.setStatus("IN_PROGRESS");
        inspection.setInspectorId(TenantContext.getCurrentUserId());
        inspection = inspectionRepository.save(inspection);

        log.info("Recorded {} results for inspection {} org {}",
                results.size(), inspection.getInspectionNumber(), orgId);
        return inspection;
    }

    @Transactional
    public QcInspection finalizeInspection(UUID inspectionId, BigDecimal acceptedQty,
                                            BigDecimal rejectedQty, String notes) {
        UUID orgId = TenantContext.getCurrentOrgId();

        QcInspection inspection = inspectionRepository.findByIdAndOrgIdAndIsDeletedFalse(inspectionId, orgId)
                .orElseThrow(() -> BusinessException.notFound("QcInspection", inspectionId));

        if ("PASSED".equals(inspection.getStatus()) || "FAILED".equals(inspection.getStatus())) {
            throw new BusinessException("Inspection is already finalized",
                    "QC_ALREADY_FINALIZED", HttpStatus.BAD_REQUEST);
        }

        inspection.setAcceptedQty(acceptedQty != null ? acceptedQty : BigDecimal.ZERO);
        inspection.setRejectedQty(rejectedQty != null ? rejectedQty : BigDecimal.ZERO);
        inspection.setInspectedAt(Instant.now());
        if (notes != null) inspection.setNotes(notes);

        boolean anyFailed = inspection.getResults().stream()
                .anyMatch(r -> !r.isDeleted() && Boolean.FALSE.equals(r.getIsPassed()));

        if (rejectedQty != null && rejectedQty.compareTo(BigDecimal.ZERO) > 0) {
            inspection.setStatus(acceptedQty != null && acceptedQty.compareTo(BigDecimal.ZERO) > 0
                    ? "PARTIAL" : "FAILED");
        } else if (anyFailed) {
            inspection.setStatus("FAILED");
        } else {
            inspection.setStatus("PASSED");
        }

        inspection = inspectionRepository.save(inspection);
        log.info("Inspection {} finalized as {} (accepted={}, rejected={}) for org {}",
                inspection.getInspectionNumber(), inspection.getStatus(),
                inspection.getAcceptedQty(), inspection.getRejectedQty(), orgId);
        return inspection;
    }

    // ── Disposition ───────────────────────────────────────────────

    /**
     * Records the accept/reject/hold disposition of a finalized inspection.
     * REJECT qty (>0) writes a negative ADJUSTMENT stock movement when the
     * inspection can be tied to a warehouse (via its WORK_ORDER reference)
     * and auto-raises an OPEN NCR. HOLD only records the quarantine zone
     * reference — zones are not stock-tracked.
     */
    @Transactional
    public QcInspection recordDisposition(UUID inspectionId, String decision,
                                           BigDecimal acceptedQty, BigDecimal rejectedQty,
                                           BigDecimal holdQty, UUID quarantineZoneId,
                                           String notes) {
        UUID orgId = TenantContext.getCurrentOrgId();

        QcInspection inspection = inspectionRepository.findByIdAndOrgIdAndIsDeletedFalse(inspectionId, orgId)
                .orElseThrow(() -> BusinessException.notFound("QcInspection", inspectionId));

        if (!FINALIZED_STATUSES.contains(inspection.getStatus())) {
            throw new BusinessException("Disposition is only allowed on finalized inspections (current: "
                    + inspection.getStatus() + ")", "QC_NOT_FINALIZED", HttpStatus.BAD_REQUEST);
        }
        if (inspection.getDisposition() != null) {
            throw new BusinessException("Inspection already has a disposition: " + inspection.getDisposition(),
                    "QC_ALREADY_DISPOSITIONED", HttpStatus.BAD_REQUEST);
        }
        if (decision == null || !Set.of("ACCEPT", "REJECT", "HOLD").contains(decision)) {
            throw new BusinessException("Disposition decision must be ACCEPT, REJECT or HOLD",
                    "QC_INVALID_DISPOSITION", HttpStatus.BAD_REQUEST);
        }

        BigDecimal accepted = acceptedQty != null ? acceptedQty : BigDecimal.ZERO;
        BigDecimal rejected = rejectedQty != null ? rejectedQty : BigDecimal.ZERO;
        BigDecimal hold = holdQty != null ? holdQty : BigDecimal.ZERO;

        if (accepted.signum() < 0 || rejected.signum() < 0 || hold.signum() < 0) {
            throw new BusinessException("Disposition quantities cannot be negative",
                    "QC_DISPOSITION_QTY_MISMATCH", HttpStatus.BAD_REQUEST);
        }
        if (inspection.getInspectedQty() != null
                && accepted.add(rejected).add(hold).compareTo(inspection.getInspectedQty()) != 0) {
            throw new BusinessException("Accepted + rejected + hold quantities must equal inspected quantity "
                    + inspection.getInspectedQty(), "QC_DISPOSITION_QTY_MISMATCH", HttpStatus.BAD_REQUEST);
        }

        if (quarantineZoneId != null) {
            WarehouseZone zone = warehouseZoneRepository.findByIdAndOrgIdAndIsDeletedFalse(quarantineZoneId, orgId)
                    .orElseThrow(() -> BusinessException.notFound("WarehouseZone", quarantineZoneId));
            if (!"QUARANTINE".equals(zone.getZoneType())) {
                throw new BusinessException("Zone " + zone.getCode() + " is not a QUARANTINE zone",
                        "QC_INVALID_QUARANTINE_ZONE", HttpStatus.BAD_REQUEST);
            }
        }

        inspection.setDisposition(decision);
        inspection.setAcceptedQty(accepted);
        inspection.setRejectedQty(rejected);
        inspection.setHoldQty(hold);
        inspection.setQuarantineZoneId(quarantineZoneId);
        inspection.setDispositionNotes(notes);
        inspection.setDispositionAt(Instant.now());
        inspection.setDispositionBy(TenantContext.getCurrentUserId());

        if (rejected.compareTo(BigDecimal.ZERO) > 0) {
            UUID warehouseId = resolveWarehouseId(inspection, orgId);
            if (warehouseId != null) {
                inventoryService.recordMovement(new StockMovementRequest(
                        inspection.getItemId(),
                        warehouseId,
                        MovementType.ADJUSTMENT,
                        rejected.negate(),
                        null,
                        LocalDate.now(),
                        ReferenceType.STOCK_ADJUSTMENT,
                        inspection.getId(),
                        inspection.getInspectionNumber(),
                        "QC rejection — " + inspection.getInspectionNumber(),
                        inspection.getBatchId()
                ));
            } else {
                log.warn("QC inspection {} disposition rejected {} units but has no warehouse context — "
                        + "no stock movement recorded", inspection.getInspectionNumber(), rejected);
            }

            createNcr(inspection.getId(), inspection.getItemId(), resolveBatchNumber(inspection, orgId),
                    "MAJOR",
                    notes != null && !notes.isBlank() ? notes : "QC rejection on " + inspection.getInspectionNumber(),
                    "Auto-created from disposition of inspection " + inspection.getInspectionNumber()
                            + " (rejected qty " + rejected + ")");
        }

        inspection = inspectionRepository.save(inspection);
        log.info("Recorded disposition {} on inspection {} (accepted={}, rejected={}, hold={}) for org {}",
                decision, inspection.getInspectionNumber(), accepted, rejected, hold, orgId);
        return inspection;
    }

    /** Warehouse context only exists when the inspection references a work order. */
    private UUID resolveWarehouseId(QcInspection inspection, UUID orgId) {
        if (!"WORK_ORDER".equals(inspection.getReferenceType()) || inspection.getReferenceId() == null) {
            return null;
        }
        return workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(inspection.getReferenceId(), orgId)
                .map(WorkOrder::getWarehouseId)
                .orElse(null);
    }

    private String resolveBatchNumber(QcInspection inspection, UUID orgId) {
        if (inspection.getBatchId() == null) return null;
        return stockBatchRepository.findByIdAndOrgIdAndIsDeletedFalse(inspection.getBatchId(), orgId)
                .map(b -> b.getBatchNumber())
                .orElse(null);
    }

    // ── Non-Conformance Reports ───────────────────────────────────

    @Transactional
    public NonConformanceReport createNcr(UUID qcInspectionId, UUID itemId, String batchNumber,
                                           String severity, String reason, String description) {
        UUID orgId = TenantContext.getCurrentOrgId();

        String sev = severity != null ? severity : "MAJOR";
        if (!Set.of("MINOR", "MAJOR", "CRITICAL").contains(sev)) {
            throw new BusinessException("Severity must be MINOR, MAJOR or CRITICAL",
                    "NCR_INVALID_SEVERITY", HttpStatus.BAD_REQUEST);
        }

        int nextNum = ncrRepository.findMaxNcrNumber(orgId) + 1;
        String ncrNumber = String.format("NCR-%05d", nextNum);

        NonConformanceReport ncr = NonConformanceReport.builder()
                .ncrNumber(ncrNumber)
                .qcInspectionId(qcInspectionId)
                .itemId(itemId)
                .batchNumber(batchNumber)
                .severity(sev)
                .reason(reason)
                .description(description)
                .status("OPEN")
                .build();
        ncr = ncrRepository.save(ncr);

        log.info("Created NCR {} ({}) for item {} org {}", ncrNumber, sev, itemId, orgId);
        return ncr;
    }

    @Transactional(readOnly = true)
    public Page<NonConformanceReport> listNcrs(String status, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (status != null && !status.isBlank()) {
            return ncrRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(orgId, status, pageable);
        }
        return ncrRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId, pageable);
    }

    @Transactional(readOnly = true)
    public NonConformanceReport getNcr(UUID id) {
        return ncrRepository.findByIdAndOrgIdAndIsDeletedFalse(id, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("NonConformanceReport", id));
    }

    /** Updates corrective action / root cause and optionally moves OPEN → IN_PROGRESS. */
    @Transactional
    public NonConformanceReport updateNcr(UUID id, String correctiveAction, String rootCause, String status) {
        NonConformanceReport ncr = getNcr(id);

        if ("CLOSED".equals(ncr.getStatus())) {
            throw new BusinessException("NCR " + ncr.getNcrNumber() + " is already closed",
                    "NCR_ALREADY_CLOSED", HttpStatus.BAD_REQUEST);
        }
        if (status != null && !"IN_PROGRESS".equals(status)) {
            throw new BusinessException("NCR status can only be moved to IN_PROGRESS here — use close endpoint to close",
                    "NCR_INVALID_STATUS", HttpStatus.BAD_REQUEST);
        }

        if (correctiveAction != null) ncr.setCorrectiveAction(correctiveAction);
        if (rootCause != null) ncr.setRootCause(rootCause);
        if (status != null) ncr.setStatus(status);

        return ncrRepository.save(ncr);
    }

    @Transactional
    public NonConformanceReport closeNcr(UUID id) {
        NonConformanceReport ncr = getNcr(id);

        if ("CLOSED".equals(ncr.getStatus())) {
            throw new BusinessException("NCR " + ncr.getNcrNumber() + " is already closed",
                    "NCR_ALREADY_CLOSED", HttpStatus.BAD_REQUEST);
        }

        ncr.setStatus("CLOSED");
        ncr.setClosedAt(Instant.now());
        ncr.setClosedBy(TenantContext.getCurrentUserId());
        ncr = ncrRepository.save(ncr);

        log.info("Closed NCR {} for org {}", ncr.getNcrNumber(), TenantContext.getCurrentOrgId());
        return ncr;
    }

    // ── Certificate of Analysis ───────────────────────────────────

    /** Structured CoA document for a finalized inspection (JSON only, no PDF). */
    @Transactional(readOnly = true)
    public Map<String, Object> generateCoa(UUID inspectionId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        QcInspection inspection = inspectionRepository.findByIdAndOrgIdAndIsDeletedFalse(inspectionId, orgId)
                .orElseThrow(() -> BusinessException.notFound("QcInspection", inspectionId));

        if (!FINALIZED_STATUSES.contains(inspection.getStatus())) {
            throw new BusinessException("Certificate of Analysis is only available for finalized inspections",
                    "QC_NOT_FINALIZED", HttpStatus.BAD_REQUEST);
        }

        Map<String, Object> coa = new LinkedHashMap<>();
        coa.put("documentType", "CERTIFICATE_OF_ANALYSIS");
        coa.put("organisationName", organisationRepository.findById(orgId)
                .map(Organisation::getName).orElse(null));

        itemRepository.findByIdAndOrgIdAndIsDeletedFalse(inspection.getItemId(), orgId)
                .ifPresentOrElse(item -> {
                    coa.put("itemName", item.getName());
                    coa.put("itemSku", item.getSku());
                }, () -> {
                    coa.put("itemName", null);
                    coa.put("itemSku", null);
                });

        coa.put("batchNumber", resolveBatchNumber(inspection, orgId));
        coa.put("inspectionNumber", inspection.getInspectionNumber());
        coa.put("inspectionType", inspection.getInspectionType());
        coa.put("inspectionDate", inspection.getInspectedAt());
        coa.put("inspectorId", inspection.getInspectorId());
        coa.put("inspectedQty", inspection.getInspectedQty());

        List<Map<String, Object>> parameters = new ArrayList<>();
        for (QcInspectionResult result : inspection.getResults()) {
            if (result.isDeleted()) continue;
            Map<String, Object> row = new LinkedHashMap<>();
            parameterRepository.findById(result.getParameterId()).ifPresentOrElse(param -> {
                row.put("parameter", param.getName());
                row.put("unit", param.getUnit());
                row.put("specMin", param.getMinValue());
                row.put("specMax", param.getMaxValue());
                row.put("acceptableValues", param.getAcceptableValues());
            }, () -> row.put("parameter", null));
            row.put("measuredValue", result.getMeasuredValue());
            row.put("numericValue", result.getNumericValue());
            row.put("passed", result.getIsPassed());
            parameters.add(row);
        }
        coa.put("parameters", parameters);

        coa.put("overallResult", inspection.getStatus());

        Map<String, Object> disposition = new LinkedHashMap<>();
        disposition.put("decision", inspection.getDisposition());
        disposition.put("acceptedQty", inspection.getAcceptedQty());
        disposition.put("rejectedQty", inspection.getRejectedQty());
        disposition.put("holdQty", inspection.getHoldQty());
        disposition.put("quarantineZoneId", inspection.getQuarantineZoneId());
        disposition.put("notes", inspection.getDispositionNotes());
        disposition.put("dispositionAt", inspection.getDispositionAt());
        coa.put("disposition", disposition);

        return coa;
    }

    public record QcParameterInput(String name, String description, String parameterType,
                                    String unit, BigDecimal minValue, BigDecimal maxValue,
                                    String acceptableValues, Boolean isMandatory) {}

    public record QcResultInput(UUID parameterId, String measuredValue,
                                 BigDecimal numericValue, Boolean isPassed, String notes) {}
}
