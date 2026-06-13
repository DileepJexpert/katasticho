package com.katasticho.erp.fieldsales.service;

import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.fieldsales.entity.*;
import com.katasticho.erp.fieldsales.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Field coverage analytics (all verticals): tour-plan deviation
 * (planned vs actually worked, day by day), customer visit-frequency
 * compliance (required visits/month vs completed), and a per-salesperson
 * team dashboard for managers.
 *
 * Read-only — all data comes from tour plans, route executions, visits,
 * DCRs and GPS pings recorded elsewhere.
 */
@Service
@RequiredArgsConstructor
public class FieldCoverageService {

    private final TourPlanRepository tourPlanRepository;
    private final TourPlanEntryRepository tourPlanEntryRepository;
    private final RouteExecutionRepository routeExecutionRepository;
    private final FieldVisitRepository fieldVisitRepository;
    private final ContactRepository contactRepository;
    private final DcrReportRepository dcrReportRepository;
    private final FieldLocationPingRepository pingRepository;
    private final AppUserRepository appUserRepository;
    private final FieldHierarchyService fieldHierarchyService;

    private static boolean isAdmin() {
        String role = TenantContext.getCurrentRole();
        return role != null && (role.contains("OWNER") || role.contains("ADMIN"));
    }

    /** Non-admins may only view themselves or someone in their downline. */
    private void ensureCanView(UUID salespersonId) {
        if (isAdmin()) return;
        UUID me = TenantContext.getCurrentUserId();
        if (salespersonId != null && (salespersonId.equals(me)
                || fieldHierarchyService.isAncestor(me, salespersonId))) {
            return;
        }
        throw new BusinessException("You can only view your own team's reports",
                "FH_NOT_IN_TEAM", HttpStatus.FORBIDDEN);
    }

    /**
     * Day-by-day comparison of the salesperson's approved tour plan vs
     * what actually happened. Days are included when either side has
     * something; futures days are skipped.
     */
    @Transactional(readOnly = true)
    public Map<String, Object> deviationReport(LocalDate month, UUID salespersonId) {
        ensureCanView(salespersonId);
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate from = month.withDayOfMonth(1);
        LocalDate to = from.plusMonths(1).minusDays(1);

        Map<LocalDate, TourPlanEntry> planned = new HashMap<>();
        String planStatus = null;
        TourPlan plan = tourPlanRepository
                .findByOrgIdAndSalespersonIdAndPlanMonthAndIsDeletedFalse(orgId, salespersonId, from)
                .orElse(null);
        if (plan != null) {
            planStatus = plan.getStatus();
            for (TourPlanEntry e : tourPlanEntryRepository
                    .findByOrgIdAndTourPlanIdOrderByPlanDate(orgId, plan.getId())) {
                planned.putIfAbsent(e.getPlanDate(), e);
            }
        }

        Map<LocalDate, List<RouteExecution>> actual = routeExecutionRepository
                .findByOrgIdAndSalespersonIdAndExecutionDateBetweenAndIsDeletedFalse(
                        orgId, salespersonId, from, to)
                .stream().collect(Collectors.groupingBy(RouteExecution::getExecutionDate));

        Set<LocalDate> days = new TreeSet<>();
        days.addAll(planned.keySet());
        days.addAll(actual.keySet());

        LocalDate today = LocalDate.now();
        int asPlanned = 0, deviations = 0;
        List<Map<String, Object>> rows = new ArrayList<>();
        for (LocalDate day : days) {
            if (day.isAfter(today)) continue;
            TourPlanEntry p = planned.get(day);
            List<RouteExecution> execs = actual.getOrDefault(day, List.of());
            boolean worked = execs.stream()
                    .anyMatch(e -> "IN_PROGRESS".equals(e.getStatus()) || "COMPLETED".equals(e.getStatus()));
            String plannedActivity = p != null ? p.getActivityType() : null;

            String status;
            if (p == null) {
                status = worked ? "UNPLANNED_WORK" : "NO_PLAN";
            } else if ("FIELD_WORK".equals(plannedActivity)) {
                status = worked ? "AS_PLANNED" : "MISSED";
            } else {
                // Planned non-field day (leave/meeting/office/camp)
                status = worked ? "WORKED_ON_NON_FIELD_DAY" : "AS_PLANNED";
            }
            if ("AS_PLANNED".equals(status)) asPlanned++;
            else if (!"NO_PLAN".equals(status)) deviations++;

            int visitsCompleted = execs.stream().mapToInt(RouteExecution::getCompletedVisits).sum();
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("date", day);
            row.put("plannedActivity", plannedActivity);
            row.put("plannedArea", p != null ? p.getArea() : null);
            row.put("worked", worked);
            row.put("visitsCompleted", visitsCompleted);
            row.put("status", status);
            rows.add(row);
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("month", from);
        result.put("salespersonId", salespersonId);
        result.put("planStatus", planStatus);
        result.put("daysAsPlanned", asPlanned);
        result.put("daysDeviated", deviations);
        result.put("days", rows);
        return result;
    }

    /**
     * Visit-frequency compliance for the month: every contact with a
     * required visits/month (any vertical — set on the contact master)
     * vs completed visits, optionally restricted to one salesperson.
     */
    @Transactional(readOnly = true)
    public Map<String, Object> frequencyCompliance(LocalDate month, UUID salespersonId) {
        ensureCanView(salespersonId);
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate from = month.withDayOfMonth(1);
        LocalDate to = from.plusMonths(1).minusDays(1);

        List<Object[]> counts = salespersonId == null
                ? fieldVisitRepository.countCompletedVisitsByContact(orgId, from, to)
                : fieldVisitRepository.countCompletedVisitsByContactForSalesperson(
                        orgId, from, to, salespersonId);
        Map<UUID, Long> visitCounts = new HashMap<>();
        for (Object[] row : counts) {
            visitCounts.put((UUID) row[0], ((Number) row[1]).longValue());
        }

        List<Map<String, Object>> rows = new ArrayList<>();
        int compliant = 0;
        List<Contact> targets =
                contactRepository.findByOrgIdAndVisitsPerMonthGreaterThanAndIsDeletedFalse(orgId, 0);
        for (Contact c : targets) {
            long actualVisits = visitCounts.getOrDefault(c.getId(), 0L);
            int required = c.getVisitsPerMonth();
            boolean ok = actualVisits >= required;
            if (ok) compliant++;
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("contactId", c.getId());
            row.put("contactName", c.getDisplayName());
            row.put("category", c.getMedicalCategory());
            row.put("mrClass", c.getMrClass());
            row.put("requiredVisits", required);
            row.put("actualVisits", actualVisits);
            row.put("compliant", ok);
            rows.add(row);
        }
        // Worst gaps first
        rows.sort(Comparator
                .comparing((Map<String, Object> r) -> (Boolean) r.get("compliant"))
                .thenComparing(r -> ((Number) r.get("actualVisits")).longValue()));

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("month", from);
        result.put("totalTargets", targets.size());
        result.put("compliant", compliant);
        result.put("compliancePct", targets.isEmpty() ? BigDecimal.ZERO
                : BigDecimal.valueOf(compliant * 100.0 / targets.size()).setScale(1, RoundingMode.HALF_UP));
        result.put("contacts", rows);
        return result;
    }

    /** Per-salesperson roll-up for a date range — the manager's team view. */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> teamDashboard(LocalDate from, LocalDate to) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<RouteExecution> executions = routeExecutionRepository
                .findByOrgIdAndExecutionDateBetweenAndIsDeletedFalse(orgId, from, to);

        Map<UUID, List<RouteExecution>> bySalesperson = executions.stream()
                .collect(Collectors.groupingBy(RouteExecution::getSalespersonId));
        // A manager sees only their downline; admins see the whole org.
        if (!isAdmin()) {
            bySalesperson.keySet().retainAll(
                    fieldHierarchyService.downlineUserIds(TenantContext.getCurrentUserId()));
        }
        Map<UUID, String> names = appUserRepository.findAllById(bySalesperson.keySet()).stream()
                .collect(Collectors.toMap(AppUser::getId,
                        u -> u.getFullName() != null ? u.getFullName() : ""));

        Instant fromInstant = from.atStartOfDay().toInstant(ZoneOffset.UTC);
        Instant toInstant = to.plusDays(1).atStartOfDay().toInstant(ZoneOffset.UTC);

        List<Map<String, Object>> rows = new ArrayList<>();
        for (Map.Entry<UUID, List<RouteExecution>> entry : bySalesperson.entrySet()) {
            UUID salespersonId = entry.getKey();
            List<RouteExecution> execs = entry.getValue();

            int planned = execs.stream().mapToInt(RouteExecution::getPlannedVisits).sum();
            int completed = execs.stream().mapToInt(RouteExecution::getCompletedVisits).sum();
            BigDecimal orders = execs.stream().map(RouteExecution::getTotalOrdersValue)
                    .filter(Objects::nonNull).reduce(BigDecimal.ZERO, BigDecimal::add);
            BigDecimal collections = execs.stream().map(RouteExecution::getTotalCollections)
                    .filter(Objects::nonNull).reduce(BigDecimal.ZERO, BigDecimal::add);

            List<DcrReport> dcrs = dcrReportRepository
                    .findByOrgIdAndSalespersonIdAndReportDateBetweenAndIsDeletedFalseOrderByReportDateDesc(
                            orgId, salespersonId, from, to);
            long dcrsSubmitted = dcrs.stream()
                    .filter(d -> "SUBMITTED".equals(d.getStatus()) || "APPROVED".equals(d.getStatus()))
                    .count();

            List<FieldLocationPing> pings = pingRepository
                    .findByOrgIdAndSalespersonIdAndRecordedAtBetweenOrderByRecordedAtAsc(
                            orgId, salespersonId, fromInstant, toInstant);
            double meters = 0;
            for (int i = 1; i < pings.size(); i++) {
                meters += FieldTrackingService.distanceMeters(
                        pings.get(i - 1).getLatitude(), pings.get(i - 1).getLongitude(),
                        pings.get(i).getLatitude(), pings.get(i).getLongitude());
            }

            Map<String, Object> row = new LinkedHashMap<>();
            row.put("salespersonId", salespersonId);
            row.put("salespersonName", names.getOrDefault(salespersonId, ""));
            row.put("routeDays", execs.stream().map(RouteExecution::getExecutionDate).distinct().count());
            row.put("visitsPlanned", planned);
            row.put("visitsCompleted", completed);
            row.put("completionPct", planned == 0 ? BigDecimal.ZERO
                    : BigDecimal.valueOf(completed * 100.0 / planned).setScale(1, RoundingMode.HALF_UP));
            row.put("ordersValue", orders);
            row.put("collections", collections);
            row.put("distanceKm",
                    BigDecimal.valueOf(meters / 1000.0).setScale(1, RoundingMode.HALF_UP));
            row.put("dcrsSubmitted", dcrsSubmitted);
            rows.add(row);
        }
        rows.sort(Comparator.comparing(r -> ((BigDecimal) r.get("ordersValue")).negate()));
        return rows;
    }
}
