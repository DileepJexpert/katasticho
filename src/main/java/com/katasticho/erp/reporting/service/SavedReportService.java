package com.katasticho.erp.reporting.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.reporting.dto.ReportScheduleRequest;
import com.katasticho.erp.reporting.dto.SavedReportRequest;
import com.katasticho.erp.reporting.entity.ReportSchedule;
import com.katasticho.erp.reporting.entity.SavedReport;
import com.katasticho.erp.reporting.repository.ReportScheduleRepository;
import com.katasticho.erp.reporting.repository.SavedReportRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class SavedReportService {

    private final SavedReportRepository savedReportRepository;
    private final ReportScheduleRepository reportScheduleRepository;
    private final ObjectMapper objectMapper;

    // -------------------------------------------------------------------------
    // Saved Reports
    // -------------------------------------------------------------------------

    /**
     * Returns all non-deleted saved reports visible to the given user within an org:
     * reports the user owns, plus any public reports created by other org members.
     */
    @Transactional(readOnly = true)
    public List<SavedReport> list(UUID orgId, UUID userId) {
        return savedReportRepository.findByOrgIdAndUser(orgId, userId);
    }

    /**
     * Persists a new saved report owned by the current user.
     */
    @Transactional
    public SavedReport create(UUID orgId, UUID userId, SavedReportRequest req) {
        SavedReport report = SavedReport.builder()
                .orgId(orgId)
                .createdBy(userId)
                .name(req.getName())
                .description(req.getDescription())
                .baseReportKey(req.getBaseReportKey())
                .columnKeys(toJson(req.getColumnKeys()))
                .filters(toJson(req.getFilters()))
                .tags(toJson(req.getTags()))
                .isPublic(req.isPublic())
                .deleted(false)
                .build();
        return savedReportRepository.save(report);
    }

    /**
     * Updates an existing saved report. Only the owner may update.
     */
    @Transactional
    public SavedReport update(UUID orgId, UUID userId, UUID id, SavedReportRequest req) {
        SavedReport report = findOwnedReport(orgId, userId, id);
        report.setName(req.getName());
        report.setDescription(req.getDescription());
        report.setBaseReportKey(req.getBaseReportKey());
        report.setColumnKeys(toJson(req.getColumnKeys()));
        report.setFilters(toJson(req.getFilters()));
        report.setTags(toJson(req.getTags()));
        report.setPublic(req.isPublic());
        return savedReportRepository.save(report);
    }

    /**
     * Soft-deletes a saved report. Only the owner may delete.
     */
    @Transactional
    public void delete(UUID orgId, UUID userId, UUID id) {
        SavedReport report = findOwnedReport(orgId, userId, id);
        report.setDeleted(true);
        savedReportRepository.save(report);
    }

    // -------------------------------------------------------------------------
    // Report Schedules
    // -------------------------------------------------------------------------

    /**
     * Creates a new delivery schedule for an existing saved report.
     */
    @Transactional
    public ReportSchedule addSchedule(UUID orgId, UUID savedReportId, ReportScheduleRequest req) {
        // Ensure the parent report exists and belongs to this org
        savedReportRepository.findById(savedReportId)
                .filter(r -> orgId.equals(r.getOrgId()) && !r.isDeleted())
                .orElseThrow(() -> BusinessException.notFound("SavedReport", savedReportId));

        ReportSchedule schedule = ReportSchedule.builder()
                .orgId(orgId)
                .savedReportId(savedReportId)
                .frequency(req.getFrequency())
                .dayOfWeek(req.getDayOfWeek())
                .dayOfMonth(req.getDayOfMonth())
                .sendTime(req.getSendTime())
                .recipientEmails(toJson(req.getRecipientEmails()))
                .subjectTemplate(req.getSubjectTemplate())
                .active(req.isActive())
                .build();
        return reportScheduleRepository.save(schedule);
    }

    /**
     * Returns all schedules attached to a given saved report in this org.
     */
    @Transactional(readOnly = true)
    public List<ReportSchedule> listSchedules(UUID orgId, UUID savedReportId) {
        return reportScheduleRepository.findBySavedReportIdAndOrgId(savedReportId, orgId);
    }

    /**
     * Permanently removes a schedule by id (org-scoped).
     */
    @Transactional
    public void deleteSchedule(UUID orgId, UUID scheduleId) {
        ReportSchedule schedule = reportScheduleRepository.findById(scheduleId)
                .filter(s -> orgId.equals(s.getOrgId()))
                .orElseThrow(() -> BusinessException.notFound("ReportSchedule", scheduleId));
        reportScheduleRepository.delete(schedule);
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    /**
     * Loads a SavedReport that must (a) exist, (b) belong to the org, (c) not be deleted,
     * and (d) be owned by the requesting user.  Throws BusinessException otherwise.
     */
    private SavedReport findOwnedReport(UUID orgId, UUID userId, UUID id) {
        SavedReport report = savedReportRepository.findById(id)
                .filter(r -> orgId.equals(r.getOrgId()) && !r.isDeleted())
                .orElseThrow(() -> BusinessException.notFound("SavedReport", id));
        if (!userId.equals(report.getCreatedBy())) {
            throw BusinessException.accessDenied(
                    "Only the report owner may modify SavedReport " + id);
        }
        return report;
    }

    /** Serialises any value to a JSON string; returns null for null input. */
    private String toJson(Object value) {
        if (value == null) return null;
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JsonProcessingException e) {
            log.warn("Failed to serialise value to JSON: {}", e.getMessage());
            return value.toString();
        }
    }
}
