package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.manufacturing.entity.MaintenanceSchedule;
import com.katasticho.erp.manufacturing.entity.MaintenanceWorkOrder;
import com.katasticho.erp.manufacturing.entity.Workstation;
import com.katasticho.erp.manufacturing.repository.MaintenanceScheduleRepository;
import com.katasticho.erp.manufacturing.repository.MaintenanceWorkOrderRepository;
import com.katasticho.erp.manufacturing.repository.WorkstationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.*;

/**
 * Maintenance management for workstations. Two flows:
 * <ul>
 *   <li><b>Preventive schedules</b> — CRUD a schedule per workstation. The
 *       {@code generateWorkOrdersForDueSchedules(asOf)} call creates a DRAFT
 *       work order for every active schedule whose nextDueDate ≤ asOf, used
 *       both by the manual "generate now" button and the daily automation
 *       job.</li>
 *   <li><b>Maintenance work orders</b> — DRAFT → IN_PROGRESS → COMPLETED with
 *       downtime accounting. completed() rolls the linked schedule's
 *       lastCompletedDate / nextDueDate forward.</li>
 * </ul>
 * Downtime reporting aggregates completed WOs in a date range by workstation
 * so the floor can see which machines are eating production hours.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class MaintenanceService {

    private final MaintenanceScheduleRepository scheduleRepository;
    private final MaintenanceWorkOrderRepository workOrderRepository;
    private final WorkstationRepository workstationRepository;
    private final Clock clock;

    // ─────────── Schedules ───────────

    public List<MaintenanceSchedule> listSchedules() {
        return scheduleRepository.findByOrgIdAndIsDeletedFalseOrderByNextDueDateAsc(orgId());
    }

    public List<MaintenanceSchedule> listSchedulesForWorkstation(UUID workstationId) {
        return scheduleRepository.findByOrgIdAndWorkstationIdAndIsDeletedFalseOrderByNextDueDateAsc(
                orgId(), workstationId);
    }

    /** Schedules whose next-due is on or before {@code cutoff}, active only. */
    public List<MaintenanceSchedule> listDueSchedules(LocalDate cutoff) {
        return scheduleRepository
                .findByOrgIdAndIsDeletedFalseAndActiveTrueAndNextDueDateLessThanEqualOrderByNextDueDateAsc(
                        orgId(), cutoff);
    }

    public MaintenanceSchedule getSchedule(UUID id) {
        return scheduleRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId())
                .orElseThrow(() -> BusinessException.notFound("MaintenanceSchedule", id));
    }

    @Transactional
    public MaintenanceSchedule createSchedule(MaintenanceSchedule input) {
        UUID org = orgId();
        ensureWorkstation(input.getWorkstationId(), org);

        if (input.getCode() != null && !input.getCode().isBlank()) {
            scheduleRepository.findByOrgIdAndCodeAndIsDeletedFalse(org, input.getCode())
                    .ifPresent(existing -> {
                        throw new BusinessException(
                                "Maintenance schedule code '" + input.getCode() + "' already exists",
                                "MAINTENANCE_DUPLICATE_CODE", HttpStatus.CONFLICT);
                    });
        }
        if (input.getFrequencyDays() == null || input.getFrequencyDays() <= 0) {
            throw new BusinessException(
                    "Frequency in days must be a positive number",
                    "MAINTENANCE_BAD_FREQUENCY", HttpStatus.BAD_REQUEST);
        }
        if (input.getNextDueDate() == null) {
            input.setNextDueDate(today().plusDays(input.getFrequencyDays()));
        }
        input.setOrgId(org);
        input.setId(null);
        input.setDeleted(false);
        return scheduleRepository.save(input);
    }

    @Transactional
    public MaintenanceSchedule updateSchedule(UUID id, MaintenanceSchedule updates) {
        MaintenanceSchedule existing = getSchedule(id);
        existing.setTitle(updates.getTitle());
        existing.setDescription(updates.getDescription());
        existing.setFrequencyDays(updates.getFrequencyDays());
        existing.setEstimatedDurationMin(updates.getEstimatedDurationMin());
        existing.setAssignedToUserId(updates.getAssignedToUserId());
        existing.setActive(updates.isActive());
        if (updates.getNextDueDate() != null) {
            existing.setNextDueDate(updates.getNextDueDate());
        }
        return scheduleRepository.save(existing);
    }

    @Transactional
    public void deleteSchedule(UUID id) {
        MaintenanceSchedule existing = getSchedule(id);
        existing.setDeleted(true);
        scheduleRepository.save(existing);
    }

    /**
     * For every active schedule due on or before {@code asOf} create a DRAFT
     * maintenance work order if one isn't already open (DRAFT or IN_PROGRESS)
     * for that schedule. Returns the list of newly created WOs.
     */
    @Transactional
    public List<MaintenanceWorkOrder> generateWorkOrdersForDueSchedules(LocalDate asOf) {
        UUID org = orgId();
        LocalDate cutoff = (asOf != null) ? asOf : today();
        List<MaintenanceSchedule> due = listDueSchedules(cutoff);
        List<MaintenanceWorkOrder> created = new ArrayList<>();
        for (MaintenanceSchedule sch : due) {
            if (hasOpenWorkOrderForSchedule(org, sch.getId())) continue;
            MaintenanceWorkOrder wo = MaintenanceWorkOrder.builder()
                    .workstationId(sch.getWorkstationId())
                    .scheduleId(sch.getId())
                    .maintenanceType("PREVENTIVE")
                    .status("DRAFT")
                    .priority("NORMAL")
                    .title(sch.getTitle())
                    .description(sch.getDescription())
                    .assignedToUserId(sch.getAssignedToUserId())
                    .reportedAt(Instant.now(clock))
                    .build();
            wo.setOrgId(org);
            wo.setMwoNumber(nextMwoNumber(org));
            created.add(workOrderRepository.save(wo));
        }
        log.info("Maintenance schedule sweep ({}): {} due, {} new WOs", cutoff, due.size(), created.size());
        return created;
    }

    private boolean hasOpenWorkOrderForSchedule(UUID org, UUID scheduleId) {
        List<MaintenanceWorkOrder> all = workOrderRepository.findByOrgIdAndIsDeletedFalseOrderByReportedAtDesc(org);
        return all.stream().anyMatch(w ->
                scheduleId.equals(w.getScheduleId())
                        && ("DRAFT".equals(w.getStatus()) || "IN_PROGRESS".equals(w.getStatus())));
    }

    // ─────────── Work Orders ───────────

    public List<MaintenanceWorkOrder> listWorkOrders() {
        return workOrderRepository.findByOrgIdAndIsDeletedFalseOrderByReportedAtDesc(orgId());
    }

    public List<MaintenanceWorkOrder> listWorkOrdersByStatus(String status) {
        return workOrderRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByReportedAtDesc(
                orgId(), status.toUpperCase(Locale.ROOT));
    }

    public List<MaintenanceWorkOrder> listWorkOrdersForWorkstation(UUID workstationId) {
        return workOrderRepository.findByOrgIdAndWorkstationIdAndIsDeletedFalseOrderByReportedAtDesc(
                orgId(), workstationId);
    }

    public MaintenanceWorkOrder getWorkOrder(UUID id) {
        return workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId())
                .orElseThrow(() -> BusinessException.notFound("MaintenanceWorkOrder", id));
    }

    /** Create an ad-hoc maintenance WO — BREAKDOWN/INSPECTION/PREVENTIVE. */
    @Transactional
    public MaintenanceWorkOrder createWorkOrder(MaintenanceWorkOrder input) {
        UUID org = orgId();
        ensureWorkstation(input.getWorkstationId(), org);
        validateMaintenanceType(input.getMaintenanceType());
        if (input.getPriority() == null) input.setPriority("NORMAL");
        validatePriority(input.getPriority());
        if (input.getTitle() == null || input.getTitle().isBlank()) {
            throw new BusinessException("Title is required",
                    "MAINTENANCE_TITLE_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        input.setOrgId(org);
        input.setId(null);
        input.setDeleted(false);
        input.setStatus("DRAFT");
        if (input.getReportedAt() == null) input.setReportedAt(Instant.now(clock));
        input.setMwoNumber(nextMwoNumber(org));
        input.setStartedAt(null);
        input.setCompletedAt(null);
        input.setDowntimeMinutes(null);
        return workOrderRepository.save(input);
    }

    @Transactional
    public MaintenanceWorkOrder startWorkOrder(UUID id) {
        MaintenanceWorkOrder wo = getWorkOrder(id);
        if (!"DRAFT".equals(wo.getStatus())) {
            throw new BusinessException(
                    "Only DRAFT maintenance work orders can be started (was " + wo.getStatus() + ")",
                    "MAINTENANCE_NOT_DRAFT", HttpStatus.CONFLICT);
        }
        wo.setStatus("IN_PROGRESS");
        wo.setStartedAt(Instant.now(clock));
        return workOrderRepository.save(wo);
    }

    @Transactional
    public MaintenanceWorkOrder completeWorkOrder(UUID id, String notes,
                                                  java.math.BigDecimal cost) {
        MaintenanceWorkOrder wo = getWorkOrder(id);
        if (!"IN_PROGRESS".equals(wo.getStatus())) {
            throw new BusinessException(
                    "Only IN_PROGRESS maintenance work orders can be completed (was " + wo.getStatus() + ")",
                    "MAINTENANCE_NOT_IN_PROGRESS", HttpStatus.CONFLICT);
        }
        Instant now = Instant.now(clock);
        wo.setCompletedAt(now);
        wo.setCompletedBy(TenantContext.getCurrentUserId());
        wo.setCompletionNotes(notes);
        if (cost != null) wo.setCost(cost);
        wo.setDowntimeMinutes((int) ChronoUnit.MINUTES.between(wo.getStartedAt(), now));
        wo.setStatus("COMPLETED");
        wo = workOrderRepository.save(wo);

        // Roll the linked schedule forward.
        if (wo.getScheduleId() != null) {
            scheduleRepository.findByIdAndOrgIdAndIsDeletedFalse(wo.getScheduleId(), wo.getOrgId())
                    .ifPresent(sch -> {
                        LocalDate completedDate = now.atZone(ZoneOffset.UTC).toLocalDate();
                        sch.setLastCompletedDate(completedDate);
                        sch.setNextDueDate(completedDate.plusDays(sch.getFrequencyDays()));
                        scheduleRepository.save(sch);
                    });
        }
        return wo;
    }

    @Transactional
    public MaintenanceWorkOrder cancelWorkOrder(UUID id, String reason) {
        MaintenanceWorkOrder wo = getWorkOrder(id);
        if ("COMPLETED".equals(wo.getStatus()) || "CANCELLED".equals(wo.getStatus())) {
            throw new BusinessException(
                    "Cannot cancel a " + wo.getStatus() + " maintenance work order",
                    "MAINTENANCE_FINAL_STATE", HttpStatus.CONFLICT);
        }
        wo.setStatus("CANCELLED");
        if (reason != null && !reason.isBlank()) {
            wo.setCompletionNotes(reason);
        }
        return workOrderRepository.save(wo);
    }

    // ─────────── Reports ───────────

    /**
     * Downtime aggregated per workstation for the COMPLETED maintenance work
     * orders that completed within [from, to]. Returns
     * <pre>
     * { items: [ { workstationId, workstationName, count, totalMinutes,
     *              totalCost, types: { PREVENTIVE: n, BREAKDOWN: n, … } } ],
     *   totalMinutes, totalCount }
     * </pre>
     */
    public Map<String, Object> downtimeReport(LocalDate from, LocalDate to) {
        UUID org = orgId();
        Instant fromI = from.atStartOfDay(ZoneOffset.UTC).toInstant();
        Instant toI = to.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant();
        List<MaintenanceWorkOrder> completed = workOrderRepository
                .findByOrgIdAndStatusAndCompletedAtBetweenAndIsDeletedFalseOrderByCompletedAtAsc(
                        org, "COMPLETED", fromI, toI);

        Map<UUID, Workstation> wsCache = new HashMap<>();
        Map<UUID, Map<String, Object>> byWs = new LinkedHashMap<>();
        long totalMinutes = 0;
        for (MaintenanceWorkOrder wo : completed) {
            Map<String, Object> row = byWs.computeIfAbsent(wo.getWorkstationId(), id -> {
                Map<String, Object> r = new LinkedHashMap<>();
                Workstation ws = wsCache.computeIfAbsent(id, k ->
                        workstationRepository.findByIdAndOrgIdAndIsDeletedFalse(k, org).orElse(null));
                r.put("workstationId", id);
                r.put("workstationName", ws != null ? ws.getName() : "(deleted)");
                r.put("workstationCode", ws != null ? ws.getCode() : "");
                r.put("count", 0);
                r.put("totalMinutes", 0L);
                r.put("totalCost", java.math.BigDecimal.ZERO);
                r.put("types", new LinkedHashMap<String, Integer>());
                return r;
            });
            row.put("count", (Integer) row.get("count") + 1);
            int dt = wo.getDowntimeMinutes() != null ? wo.getDowntimeMinutes() : 0;
            row.put("totalMinutes", (Long) row.get("totalMinutes") + dt);
            totalMinutes += dt;
            if (wo.getCost() != null) {
                row.put("totalCost", ((java.math.BigDecimal) row.get("totalCost")).add(wo.getCost()));
            }
            @SuppressWarnings("unchecked")
            Map<String, Integer> types = (Map<String, Integer>) row.get("types");
            types.merge(wo.getMaintenanceType(), 1, Integer::sum);
        }

        // Sort by totalMinutes desc — worst offenders first.
        List<Map<String, Object>> rows = new ArrayList<>(byWs.values());
        rows.sort((a, b) -> Long.compare((Long) b.get("totalMinutes"), (Long) a.get("totalMinutes")));

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("from", from);
        out.put("to", to);
        out.put("totalCount", completed.size());
        out.put("totalMinutes", totalMinutes);
        out.put("items", rows);
        return out;
    }

    // ─────────── Helpers ───────────

    private Workstation ensureWorkstation(UUID workstationId, UUID org) {
        if (workstationId == null) {
            throw new BusinessException("workstationId is required",
                    "MAINTENANCE_WORKSTATION_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        return workstationRepository.findByIdAndOrgIdAndIsDeletedFalse(workstationId, org)
                .orElseThrow(() -> BusinessException.notFound("Workstation", workstationId));
    }

    private void validateMaintenanceType(String type) {
        if (type == null || !List.of("PREVENTIVE", "BREAKDOWN", "INSPECTION").contains(type)) {
            throw new BusinessException(
                    "maintenanceType must be PREVENTIVE, BREAKDOWN, or INSPECTION",
                    "MAINTENANCE_BAD_TYPE", HttpStatus.BAD_REQUEST);
        }
    }

    private void validatePriority(String priority) {
        if (!List.of("URGENT", "HIGH", "NORMAL", "LOW").contains(priority)) {
            throw new BusinessException(
                    "priority must be URGENT, HIGH, NORMAL, or LOW",
                    "MAINTENANCE_BAD_PRIORITY", HttpStatus.BAD_REQUEST);
        }
    }

    private String nextMwoNumber(UUID org) {
        int year = today().getYear();
        String prefix = "MWO-" + year + "-";
        Optional<MaintenanceWorkOrder> latest =
                workOrderRepository.findTopByOrgIdAndMwoNumberStartingWithOrderByMwoNumberDesc(org, prefix);
        int n = latest.map(w -> {
            try { return Integer.parseInt(w.getMwoNumber().substring(prefix.length())); }
            catch (NumberFormatException e) { return 0; }
        }).orElse(0) + 1;
        return prefix + String.format("%05d", n);
    }

    private LocalDate today() {
        return LocalDate.ofInstant(Instant.now(clock), ZoneOffset.UTC);
    }

    private UUID orgId() {
        return TenantContext.getCurrentOrgId();
    }
}
