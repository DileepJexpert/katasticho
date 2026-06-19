package com.katasticho.erp.asset.service;

import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.asset.entity.FixedAsset;
import com.katasticho.erp.asset.entity.FixedAssetDepreciation;
import com.katasticho.erp.asset.repository.FixedAssetDepreciationRepository;
import com.katasticho.erp.asset.repository.FixedAssetRepository;
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
 * Fixed Assets + Depreciation, with India's dual schedule:
 * <ul>
 *   <li><b>Book (Companies Act):</b> SLM or WDV per asset, posted to the GL
 *       (DR Depreciation Expense / CR Accumulated Depreciation) on a periodic
 *       depreciation run — idempotent per (asset, period).</li>
 *   <li><b>Income-Tax (block of assets):</b> WDV at the prescribed rate with the
 *       180-day half-rate rule, computed for the return only (never posted).</li>
 * </ul>
 */
@Service
@RequiredArgsConstructor
public class FixedAssetService {

    private static final BigDecimal HUNDRED = new BigDecimal("100");
    private static final BigDecimal TWELVE = new BigDecimal("12");
    private static final String DEFAULT_ASSET_ACC = "1600";
    private static final String DEFAULT_ACCUM_ACC = "1690";
    private static final String DEFAULT_DEPEXP_ACC = "5270";

    private final FixedAssetRepository assetRepository;
    private final FixedAssetDepreciationRepository depreciationRepository;
    private final JournalService journalService;

    // ── Register CRUD ────────────────────────────────────────────────────

    @Transactional
    public FixedAsset create(FixedAsset asset) {
        UUID orgId = requireOrgId();
        if (asset.getAssetCode() == null || asset.getAssetCode().isBlank()) {
            throw new BusinessException("Asset code is required", "FA_CODE_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        if (assetRepository.existsByOrgIdAndAssetCodeAndIsDeletedFalse(orgId, asset.getAssetCode())) {
            throw new BusinessException("Asset code already exists", "FA_CODE_DUP", HttpStatus.CONFLICT);
        }
        String method = asset.getBookMethod() == null ? "" : asset.getBookMethod().toUpperCase();
        if (!method.equals("SLM") && !method.equals("WDV")) {
            throw new BusinessException("bookMethod must be SLM or WDV", "FA_BAD_METHOD", HttpStatus.BAD_REQUEST);
        }
        if (method.equals("SLM") && (asset.getBookUsefulLifeMonths() == null
                || asset.getBookUsefulLifeMonths() <= 0)) {
            throw new BusinessException("SLM needs bookUsefulLifeMonths", "FA_NEED_LIFE", HttpStatus.BAD_REQUEST);
        }
        if (method.equals("WDV") && (asset.getBookRatePct() == null
                || asset.getBookRatePct().signum() <= 0)) {
            throw new BusinessException("WDV needs bookRatePct", "FA_NEED_RATE", HttpStatus.BAD_REQUEST);
        }
        asset.setOrgId(orgId);
        asset.setBookMethod(method);
        asset.setCreatedBy(TenantContext.getCurrentUserId());
        if (asset.getResidualValue() == null) asset.setResidualValue(BigDecimal.ZERO);
        if (asset.getAccumulatedDepreciation() == null) asset.setAccumulatedDepreciation(BigDecimal.ZERO);
        defaultAccounts(asset);
        asset.setStatus("ACTIVE");
        return assetRepository.save(asset);
    }

    @Transactional(readOnly = true)
    public List<FixedAsset> list() {
        return assetRepository.findByOrgIdAndIsDeletedFalseOrderByAcquisitionDateDesc(requireOrgId());
    }

    @Transactional(readOnly = true)
    public Map<String, Object> get(UUID id) {
        FixedAsset a = load(id);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("asset", a);
        out.put("bookValue", a.bookValue());
        out.put("schedule", depreciationRepository
                .findByOrgIdAndFixedAssetIdOrderByPeriodYearAscPeriodMonthAsc(a.getOrgId(), a.getId()));
        return out;
    }

    // ── Book depreciation run (Companies Act, posts to GL) ───────────────

    /**
     * Charge book depreciation for the given month across all active assets,
     * posting ONE journal (grouped by account pair). Idempotent: assets already
     * depreciated for this period are skipped.
     */
    @Transactional
    public Map<String, Object> runDepreciation(int year, int month) {
        UUID orgId = requireOrgId();
        if (month < 1 || month > 12) {
            throw new BusinessException("month must be 1-12", "FA_BAD_MONTH", HttpStatus.BAD_REQUEST);
        }
        LocalDate periodEnd = YearMonth.of(year, month).atEndOfMonth();

        record Charge(FixedAsset asset, BigDecimal opening, BigDecimal amount, BigDecimal closing) {}
        List<Charge> charges = new ArrayList<>();

        for (FixedAsset a : assetRepository
                .findByOrgIdAndStatusAndIsDeletedFalseOrderByAcquisitionDateAsc(orgId, "ACTIVE")) {
            if (a.getAcquisitionDate().isAfter(periodEnd)) continue; // not yet acquired
            if (depreciationRepository.existsByOrgIdAndFixedAssetIdAndPeriodYearAndPeriodMonth(
                    orgId, a.getId(), year, month)) {
                continue; // already charged — idempotent
            }
            BigDecimal opening = a.bookValue();
            BigDecimal amount = monthlyBookDepreciation(a);
            if (amount.signum() <= 0) continue;
            charges.add(new Charge(a, opening, amount, opening.subtract(amount)));
        }
        if (charges.isEmpty()) {
            return summary(year, month, 0, BigDecimal.ZERO, null);
        }

        // Group into journal lines: DR each dep-expense account, CR each accum account.
        Map<String, BigDecimal> debits = new LinkedHashMap<>();
        Map<String, BigDecimal> credits = new LinkedHashMap<>();
        BigDecimal total = BigDecimal.ZERO;
        for (Charge c : charges) {
            debits.merge(nz(c.asset().getDepExpenseAccountCode(), DEFAULT_DEPEXP_ACC), c.amount(), BigDecimal::add);
            credits.merge(nz(c.asset().getAccumulatedDepAccountCode(), DEFAULT_ACCUM_ACC), c.amount(), BigDecimal::add);
            total = total.add(c.amount());
        }
        List<JournalLineRequest> lines = new ArrayList<>();
        debits.forEach((acc, amt) -> lines.add(
                new JournalLineRequest(acc, amt, BigDecimal.ZERO, "Depreciation", null, null)));
        credits.forEach((acc, amt) -> lines.add(
                new JournalLineRequest(acc, BigDecimal.ZERO, amt, "Accumulated depreciation", null, null)));

        JournalEntry je = journalService.postJournal(new JournalPostRequest(
                periodEnd, "Depreciation " + year + "-" + String.format("%02d", month),
                "FIXED_ASSET", null, lines, true));

        // Persist per-asset charges + update accumulated.
        for (Charge c : charges) {
            depreciationRepository.save(FixedAssetDepreciation.builder()
                    .orgId(orgId).fixedAssetId(c.asset().getId())
                    .periodYear(year).periodMonth(month)
                    .openingWdv(c.opening()).depreciationAmount(c.amount()).closingWdv(c.closing())
                    .journalEntryId(je.getId())
                    .build());
            c.asset().setAccumulatedDepreciation(
                    c.asset().getAccumulatedDepreciation().add(c.amount()));
            assetRepository.save(c.asset());
        }
        return summary(year, month, charges.size(), total, je.getId());
    }

    /** Monthly book depreciation, floored at residual value. */
    BigDecimal monthlyBookDepreciation(FixedAsset a) {
        BigDecimal depreciable = a.getCost().subtract(a.getResidualValue());
        BigDecimal remaining = depreciable.subtract(a.getAccumulatedDepreciation());
        if (remaining.signum() <= 0) return BigDecimal.ZERO;

        BigDecimal monthly;
        if ("WDV".equals(a.getBookMethod())) {
            monthly = a.bookValue().multiply(a.getBookRatePct())
                    .divide(HUNDRED, 6, RoundingMode.HALF_UP)
                    .divide(TWELVE, 2, RoundingMode.HALF_UP);
        } else { // SLM
            monthly = depreciable.divide(
                    new BigDecimal(a.getBookUsefulLifeMonths()), 2, RoundingMode.HALF_UP);
        }
        return monthly.min(remaining).max(BigDecimal.ZERO);
    }

    // ── Disposal ─────────────────────────────────────────────────────────

    @Transactional
    public Map<String, Object> dispose(UUID id, LocalDate disposalDate, BigDecimal proceeds,
                                       String proceedsAccountCode, String gainLossAccountCode) {
        FixedAsset a = load(id);
        if (!"ACTIVE".equals(a.getStatus())) {
            throw new BusinessException("Asset is already disposed", "FA_NOT_ACTIVE", HttpStatus.BAD_REQUEST);
        }
        BigDecimal proc = proceeds == null ? BigDecimal.ZERO : proceeds;
        BigDecimal bookValue = a.bookValue();
        BigDecimal gain = proc.subtract(bookValue); // +ve gain, -ve loss

        List<JournalLineRequest> lines = new ArrayList<>();
        // Reverse accumulated depreciation and the asset cost.
        if (a.getAccumulatedDepreciation().signum() > 0) {
            lines.add(new JournalLineRequest(nz(a.getAccumulatedDepAccountCode(), DEFAULT_ACCUM_ACC),
                    a.getAccumulatedDepreciation(), BigDecimal.ZERO, "Remove accumulated depreciation", null, null));
        }
        if (proc.signum() > 0) {
            lines.add(new JournalLineRequest(req(proceedsAccountCode, "proceeds account"),
                    proc, BigDecimal.ZERO, "Disposal proceeds", null, null));
        }
        lines.add(new JournalLineRequest(nz(a.getAssetAccountCode(), DEFAULT_ASSET_ACC),
                BigDecimal.ZERO, a.getCost(), "Remove asset cost", null, null));
        if (gain.signum() > 0) {
            lines.add(new JournalLineRequest(req(gainLossAccountCode, "gain/loss account"),
                    BigDecimal.ZERO, gain, "Gain on disposal", null, null));
        } else if (gain.signum() < 0) {
            lines.add(new JournalLineRequest(req(gainLossAccountCode, "gain/loss account"),
                    gain.abs(), BigDecimal.ZERO, "Loss on disposal", null, null));
        }

        JournalEntry je = journalService.postJournal(new JournalPostRequest(
                disposalDate, "Disposal of " + a.getName(), "FIXED_ASSET", a.getId(), lines, true));

        a.setStatus("DISPOSED");
        a.setDisposalDate(disposalDate);
        a.setDisposalProceeds(proc);
        assetRepository.save(a);

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("assetId", a.getId());
        out.put("bookValue", bookValue);
        out.put("proceeds", proc);
        out.put("gainLoss", gain);
        out.put("result", gain.signum() >= 0 ? "GAIN" : "LOSS");
        out.put("journalEntryId", je.getId());
        return out;
    }

    // ── Income-tax depreciation (block of assets, WDV, computed) ─────────

    /**
     * Income-tax depreciation schedule for the FY starting in {@code fyStartYear}
     * (Apr fyStartYear – Mar fyStartYear+1), aggregated by block. WDV method at
     * the prescribed rate with the 180-day half-rate rule. Computed only — never
     * posted to the books.
     */
    @Transactional(readOnly = true)
    public Map<String, Object> incomeTaxSchedule(int fyStartYear) {
        UUID orgId = requireOrgId();
        Map<String, BigDecimal[]> byBlock = new LinkedHashMap<>(); // block -> [opening, additions, dep, closing]

        for (FixedAsset a : assetRepository.findByOrgIdAndIsDeletedFalseOrderByAcquisitionDateDesc(orgId)) {
            if (a.getItBlock() == null || a.getItRatePct() == null) continue;
            if (fyStartOf(a.getAcquisitionDate()) > fyStartYear) continue; // not yet acquired
            ItRow r = itForFy(a, fyStartYear);
            if (r == null) continue;
            BigDecimal[] agg = byBlock.computeIfAbsent(a.getItBlock(),
                    k -> new BigDecimal[]{BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO});
            agg[0] = agg[0].add(r.opening);
            agg[1] = agg[1].add(r.additions);
            agg[2] = agg[2].add(r.depreciation);
            agg[3] = agg[3].add(r.closing);
        }

        List<Map<String, Object>> blocks = new ArrayList<>();
        BigDecimal tDep = BigDecimal.ZERO;
        for (var e : byBlock.entrySet()) {
            BigDecimal[] v = e.getValue();
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("block", e.getKey());
            row.put("openingWdv", v[0]);
            row.put("additions", v[1]);
            row.put("depreciation", v[2]);
            row.put("closingWdv", v[3]);
            blocks.add(row);
            tDep = tDep.add(v[2]);
        }

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("fy", fyStartYear + "-" + ((fyStartYear + 1) % 100));
        out.put("method", "WDV (block of assets, Income-Tax Act)");
        out.put("totalDepreciation", tDep);
        out.put("blocks", blocks);
        return out;
    }

    private record ItRow(BigDecimal opening, BigDecimal additions, BigDecimal depreciation, BigDecimal closing) {}

    /** IT depreciation for one asset in the target FY via deterministic WDV replay. */
    private ItRow itForFy(FixedAsset a, int targetFy) {
        int acqFy = fyStartOf(a.getAcquisitionDate());
        BigDecimal rate = a.getItRatePct().divide(HUNDRED, 6, RoundingMode.HALF_UP);
        boolean halfInAcqFy = daysToFyEnd(a.getAcquisitionDate()) < 180;

        // Replay from acquisition FY up to (targetFy - 1) to get opening WDV.
        BigDecimal wdv = a.getCost();
        for (int fy = acqFy; fy < targetFy; fy++) {
            BigDecimal r = (fy == acqFy && halfInAcqFy) ? rate.divide(new BigDecimal("2")) : rate;
            wdv = wdv.subtract(wdv.multiply(r)).setScale(2, RoundingMode.HALF_UP);
        }
        BigDecimal opening = wdv;
        BigDecimal additions = (acqFy == targetFy) ? a.getCost() : BigDecimal.ZERO;
        BigDecimal effRate = (acqFy == targetFy && halfInAcqFy) ? rate.divide(new BigDecimal("2")) : rate;
        BigDecimal dep = opening.multiply(effRate).setScale(2, RoundingMode.HALF_UP);
        return new ItRow(opening, additions, dep, opening.subtract(dep));
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private void defaultAccounts(FixedAsset a) {
        if (a.getAssetAccountCode() == null) a.setAssetAccountCode(DEFAULT_ASSET_ACC);
        if (a.getAccumulatedDepAccountCode() == null) a.setAccumulatedDepAccountCode(DEFAULT_ACCUM_ACC);
        if (a.getDepExpenseAccountCode() == null) a.setDepExpenseAccountCode(DEFAULT_DEPEXP_ACC);
    }

    private Map<String, Object> summary(int year, int month, int count, BigDecimal total, UUID jeId) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("periodYear", year);
        out.put("periodMonth", month);
        out.put("assetCount", count);
        out.put("totalDepreciation", total);
        out.put("journalEntryId", jeId);
        return out;
    }

    private FixedAsset load(UUID id) {
        return assetRepository.findByIdAndOrgIdAndIsDeletedFalse(id, requireOrgId())
                .orElseThrow(() -> BusinessException.notFound("FixedAsset", id));
    }

    static int fyStartOf(LocalDate d) {
        return d.getMonthValue() >= 4 ? d.getYear() : d.getYear() - 1;
    }

    static long daysToFyEnd(LocalDate acq) {
        LocalDate fyEnd = LocalDate.of(fyStartOf(acq) + 1, 3, 31);
        return java.time.temporal.ChronoUnit.DAYS.between(acq, fyEnd) + 1;
    }

    private static String nz(String v, String def) {
        return v == null || v.isBlank() ? def : v;
    }

    private static String req(String v, String what) {
        if (v == null || v.isBlank()) {
            throw new BusinessException("A " + what + " is required", "FA_ACC_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        return v;
    }

    private static UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
