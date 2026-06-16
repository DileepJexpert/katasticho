package com.katasticho.erp.amortization.service;

import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.amortization.entity.AmortizationEntry;
import com.katasticho.erp.amortization.entity.AmortizationSchedule;
import com.katasticho.erp.amortization.repository.AmortizationEntryRepository;
import com.katasticho.erp.amortization.repository.AmortizationScheduleRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.*;

/**
 * Recurring amortization — prepaids, deferred income, and accruals.
 *
 * <p>A schedule spreads {@code totalAmount} over {@code numberOfPeriods}
 * starting at {@code startYear/startMonth}; each period posts ONE balanced
 * journal line-pair (DR {@code debitAccountCode} / CR {@code creditAccountCode})
 * for the period amount. The amounts are order-independent: every period is
 * {@code round(total/periods, 2)} except the last, which absorbs the rounding
 * residual so the schedule sums to exactly {@code totalAmount}. Runs are
 * idempotent per (schedule, period), mirroring depreciation.
 */
@Service
@RequiredArgsConstructor
public class AmortizationService {

    private static final Set<String> TYPES = Set.of("PREPAID", "DEFERRED_INCOME", "ACCRUAL");

    private final AmortizationScheduleRepository scheduleRepository;
    private final AmortizationEntryRepository entryRepository;
    private final JournalService journalService;

    // ── CRUD ─────────────────────────────────────────────────────────────

    @Transactional
    public AmortizationSchedule create(AmortizationSchedule s) {
        UUID orgId = requireOrgId();
        String type = s.getScheduleType() == null ? "" : s.getScheduleType().toUpperCase();
        if (!TYPES.contains(type)) {
            throw new BusinessException("scheduleType must be PREPAID, DEFERRED_INCOME or ACCRUAL",
                    "AMORT_BAD_TYPE", HttpStatus.BAD_REQUEST);
        }
        if (s.getTotalAmount() == null || s.getTotalAmount().signum() <= 0) {
            throw new BusinessException("totalAmount must be positive", "AMORT_BAD_AMOUNT", HttpStatus.BAD_REQUEST);
        }
        if (s.getNumberOfPeriods() <= 0) {
            throw new BusinessException("numberOfPeriods must be > 0", "AMORT_BAD_PERIODS", HttpStatus.BAD_REQUEST);
        }
        if (s.getStartMonth() < 1 || s.getStartMonth() > 12) {
            throw new BusinessException("startMonth must be 1-12", "AMORT_BAD_MONTH", HttpStatus.BAD_REQUEST);
        }
        if (blank(s.getDebitAccountCode()) || blank(s.getCreditAccountCode())) {
            throw new BusinessException("debitAccountCode and creditAccountCode are required",
                    "AMORT_ACC_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        s.setOrgId(orgId);
        s.setScheduleType(type);
        s.setRecognizedAmount(BigDecimal.ZERO);
        s.setStatus("ACTIVE");
        s.setCreatedBy(TenantContext.getCurrentUserId());
        return scheduleRepository.save(s);
    }

    @Transactional(readOnly = true)
    public List<AmortizationSchedule> list() {
        return scheduleRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(requireOrgId());
    }

    @Transactional(readOnly = true)
    public Map<String, Object> get(UUID id) {
        AmortizationSchedule s = load(id);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("schedule", s);
        out.put("periodAmount", standardAmount(s));
        out.put("remaining", s.getTotalAmount().subtract(s.getRecognizedAmount()));
        out.put("entries", entryRepository
                .findByOrgIdAndScheduleIdOrderByPeriodYearAscPeriodMonthAsc(s.getOrgId(), s.getId()));
        return out;
    }

    @Transactional
    public AmortizationSchedule cancel(UUID id) {
        AmortizationSchedule s = load(id);
        s.setStatus("CANCELLED");
        return scheduleRepository.save(s);
    }

    // ── Period run (posts the grouped journal) ───────────────────────────

    /**
     * Recognise all active schedules due in the given month, posting ONE
     * journal grouped by account. Idempotent per (schedule, period).
     */
    @Transactional
    public Map<String, Object> run(int year, int month) {
        UUID orgId = requireOrgId();
        if (month < 1 || month > 12) {
            throw new BusinessException("month must be 1-12", "AMORT_BAD_MONTH", HttpStatus.BAD_REQUEST);
        }
        LocalDate periodEnd = YearMonth.of(year, month).atEndOfMonth();
        int target = year * 12 + (month - 1);

        record Charge(AmortizationSchedule s, BigDecimal amount, boolean last) {}
        List<Charge> charges = new ArrayList<>();

        for (AmortizationSchedule s : scheduleRepository
                .findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtAsc(orgId, "ACTIVE")) {
            int start = s.getStartYear() * 12 + (s.getStartMonth() - 1);
            int idx = target - start;
            if (idx < 0 || idx >= s.getNumberOfPeriods()) continue;       // outside the window
            if (entryRepository.existsByOrgIdAndScheduleIdAndPeriodYearAndPeriodMonth(
                    orgId, s.getId(), year, month)) continue;             // idempotent
            boolean last = idx == s.getNumberOfPeriods() - 1;
            BigDecimal amount = periodAmount(s, idx);
            if (amount.signum() <= 0) continue;
            charges.add(new Charge(s, amount, last));
        }
        if (charges.isEmpty()) {
            return summary(year, month, 0, BigDecimal.ZERO, null);
        }

        Map<String, BigDecimal> debits = new LinkedHashMap<>();
        Map<String, BigDecimal> credits = new LinkedHashMap<>();
        BigDecimal total = BigDecimal.ZERO;
        for (Charge c : charges) {
            debits.merge(c.s().getDebitAccountCode(), c.amount(), BigDecimal::add);
            credits.merge(c.s().getCreditAccountCode(), c.amount(), BigDecimal::add);
            total = total.add(c.amount());
        }
        List<JournalLineRequest> lines = new ArrayList<>();
        debits.forEach((acc, amt) -> lines.add(
                new JournalLineRequest(acc, amt, BigDecimal.ZERO, "Amortization", null, null)));
        credits.forEach((acc, amt) -> lines.add(
                new JournalLineRequest(acc, BigDecimal.ZERO, amt, "Amortization", null, null)));

        JournalEntry je = journalService.postJournal(new JournalPostRequest(
                periodEnd, "Amortization " + year + "-" + String.format("%02d", month),
                "AMORTIZATION", null, lines, true));

        for (Charge c : charges) {
            entryRepository.save(AmortizationEntry.builder()
                    .orgId(orgId).scheduleId(c.s().getId())
                    .periodYear(year).periodMonth(month)
                    .amount(c.amount()).journalEntryId(je.getId())
                    .build());
            c.s().setRecognizedAmount(c.s().getRecognizedAmount().add(c.amount()));
            if (c.last() || c.s().getRecognizedAmount().compareTo(c.s().getTotalAmount()) >= 0) {
                c.s().setStatus("COMPLETED");
            }
            scheduleRepository.save(c.s());
        }
        return summary(year, month, charges.size(), total, je.getId());
    }

    // ── Amount math (order-independent residual) ─────────────────────────

    BigDecimal standardAmount(AmortizationSchedule s) {
        return s.getTotalAmount().divide(
                new BigDecimal(s.getNumberOfPeriods()), 2, RoundingMode.HALF_UP);
    }

    /** Period amount for 0-based index {@code idx}; the last period absorbs the residual. */
    BigDecimal periodAmount(AmortizationSchedule s, int idx) {
        BigDecimal std = standardAmount(s);
        if (idx == s.getNumberOfPeriods() - 1) {
            return s.getTotalAmount().subtract(std.multiply(new BigDecimal(s.getNumberOfPeriods() - 1)));
        }
        return std;
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private Map<String, Object> summary(int year, int month, int count, BigDecimal total, UUID jeId) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("periodYear", year);
        out.put("periodMonth", month);
        out.put("scheduleCount", count);
        out.put("totalRecognized", total);
        out.put("journalEntryId", jeId);
        return out;
    }

    private AmortizationSchedule load(UUID id) {
        return scheduleRepository.findByIdAndOrgIdAndIsDeletedFalse(id, requireOrgId())
                .orElseThrow(() -> BusinessException.notFound("AmortizationSchedule", id));
    }

    private static boolean blank(String v) {
        return v == null || v.isBlank();
    }

    private static UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
