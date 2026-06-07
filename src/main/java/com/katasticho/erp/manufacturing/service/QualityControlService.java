package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.manufacturing.entity.*;
import com.katasticho.erp.manufacturing.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class QualityControlService {

    private final QcTemplateRepository templateRepository;
    private final QcParameterRepository parameterRepository;
    private final QcInspectionRepository inspectionRepository;
    private final QcInspectionResultRepository resultRepository;

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

    public record QcParameterInput(String name, String description, String parameterType,
                                    String unit, BigDecimal minValue, BigDecimal maxValue,
                                    String acceptableValues, Boolean isMandatory) {}

    public record QcResultInput(UUID parameterId, String measuredValue,
                                 BigDecimal numericValue, Boolean isPassed, String notes) {}
}
