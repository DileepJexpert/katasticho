package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.manufacturing.entity.JobCard;
import com.katasticho.erp.manufacturing.entity.Operation;
import com.katasticho.erp.manufacturing.entity.Workstation;
import com.katasticho.erp.manufacturing.repository.JobCardRepository;
import com.katasticho.erp.manufacturing.repository.OperationRepository;
import com.katasticho.erp.manufacturing.repository.WorkstationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Tracker #92: workstation bottleneck identification.
 *
 * <p>Sums the estimated hours of every open (PENDING + IN_PROGRESS) job
 * card per workstation. Compares the queue to the workstation's
 * {@code capacityHoursPerDay} → "days of work queued". Workstations with
 * the longest queue are bottlenecks; planners surface these first when
 * deciding whether to add a shift, outsource, or buy more capacity.
 *
 * <p>Estimated hours per job card =
 * {@code (operation.setupTimeMinutes + operation.runTimeMinutesPerUnit
 * × jobCard.plannedQty) / 60}. Job cards whose operation has no time
 * standards configured contribute zero (we can't second-guess a
 * planner's missing data).
 *
 * <p>This is a deliberately simple capacity gate — full finite-capacity
 * scheduling (forward/backward, calendars, shift patterns) lives in the
 * deferred Tier-3 scheduling track. The dashboard answers the one
 * question planners actually ask first: "which workstation is choking
 * the floor right now?".
 */
@Service
@RequiredArgsConstructor
public class BottleneckService {

    private static final BigDecimal SIXTY = BigDecimal.valueOf(60);

    private final JobCardRepository jobCardRepository;
    private final OperationRepository operationRepository;
    private final WorkstationRepository workstationRepository;

    @Transactional(readOnly = true)
    public List<Map<String, Object>> workstationLoadReport() {
        UUID orgId = TenantContext.getCurrentOrgId();

        List<JobCard> open = jobCardRepository.findOpenForOrg(orgId);

        // Pre-load operations + workstations referenced by open job
        // cards in a single repo round trip each.
        Map<UUID, Operation> opsById = new HashMap<>();
        for (Operation op : operationRepository.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId)) {
            opsById.put(op.getId(), op);
        }
        Map<UUID, Workstation> wsById = new HashMap<>();
        for (Workstation ws : workstationRepository.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId)) {
            wsById.put(ws.getId(), ws);
        }

        // Workstation id -> accumulated hours + job-card count.
        Map<UUID, Bucket> buckets = new LinkedHashMap<>();

        for (JobCard jc : open) {
            UUID wsId = jc.getWorkstationId();
            if (wsId == null) continue; // Floating job card — not pinned to a workstation
            Operation op = opsById.get(jc.getOperationId());
            if (op == null) continue;
            BigDecimal minutes = BigDecimal.valueOf(op.getSetupTimeMinutes())
                    .add(op.getRunTimeMinutesPerUnit().multiply(jc.getPlannedQty()));
            BigDecimal hours = minutes.divide(SIXTY, 4, RoundingMode.HALF_UP);
            Bucket b = buckets.computeIfAbsent(wsId, k -> new Bucket());
            b.hours = b.hours.add(hours);
            b.jobCardCount++;
            if ("IN_PROGRESS".equals(jc.getStatus())) b.inProgressCount++;
        }

        // Always include workstations with no open work too — they're
        // capacity headroom the planner may want to reassign work to.
        for (Workstation ws : wsById.values()) {
            buckets.putIfAbsent(ws.getId(), new Bucket());
        }

        List<Map<String, Object>> rows = new ArrayList<>();
        for (Map.Entry<UUID, Bucket> e : buckets.entrySet()) {
            Workstation ws = wsById.get(e.getKey());
            if (ws == null) continue;
            Bucket b = e.getValue();
            BigDecimal capacity = ws.getCapacityHoursPerDay() != null
                    ? ws.getCapacityHoursPerDay() : BigDecimal.ZERO;
            BigDecimal daysOfWork = capacity.signum() > 0
                    ? b.hours.divide(capacity, 2, RoundingMode.HALF_UP)
                    : BigDecimal.ZERO;
            BigDecimal utilisationPct = capacity.signum() > 0
                    ? b.hours.divide(capacity, 4, RoundingMode.HALF_UP)
                            .multiply(BigDecimal.valueOf(100))
                            .setScale(2, RoundingMode.HALF_UP)
                    : BigDecimal.ZERO;

            Map<String, Object> row = new LinkedHashMap<>();
            row.put("workstationId", ws.getId());
            row.put("workstationCode", ws.getCode());
            row.put("workstationName", ws.getName());
            row.put("active", ws.isActive());
            row.put("hourlyRate", ws.getHourlyRate());
            row.put("capacityHoursPerDay", capacity);
            row.put("queuedHours", b.hours.setScale(2, RoundingMode.HALF_UP));
            row.put("daysOfWork", daysOfWork);
            row.put("utilisationPctOfDay", utilisationPct);
            row.put("openJobCards", b.jobCardCount);
            row.put("inProgressJobCards", b.inProgressCount);
            row.put("status", classify(b.hours, capacity));
            rows.add(row);
        }
        rows.sort(Comparator.comparing(
                (Map<String, Object> r) -> ((BigDecimal) r.get("queuedHours")))
                .reversed());
        return rows;
    }

    /**
     * Worst N workstations — used by the dashboard tile.
     */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> topBottlenecks(int limit) {
        List<Map<String, Object>> all = workstationLoadReport();
        return all.stream()
                .filter(r -> !"IDLE".equals(r.get("status")))
                .limit(Math.max(1, limit))
                .toList();
    }

    private String classify(BigDecimal hours, BigDecimal capacity) {
        if (hours.signum() == 0) return "IDLE";
        if (capacity.signum() == 0) return "UNCAPACITATED";
        // > 5 days of queued work → BOTTLENECK; > 1 day → BUSY; else OK.
        BigDecimal days = hours.divide(capacity, 4, RoundingMode.HALF_UP);
        if (days.compareTo(BigDecimal.valueOf(5)) > 0) return "BOTTLENECK";
        if (days.compareTo(BigDecimal.ONE) > 0) return "BUSY";
        return "OK";
    }

    private static class Bucket {
        BigDecimal hours = BigDecimal.ZERO;
        int jobCardCount = 0;
        int inProgressCount = 0;
    }
}
