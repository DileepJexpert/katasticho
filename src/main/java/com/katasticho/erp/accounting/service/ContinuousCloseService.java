package com.katasticho.erp.accounting.service;

import com.katasticho.erp.accounting.entity.FiscalPeriod;
import com.katasticho.erp.accounting.repository.FiscalPeriodRepository;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.amortization.entity.AmortizationSchedule;
import com.katasticho.erp.amortization.repository.AmortizationEntryRepository;
import com.katasticho.erp.amortization.repository.AmortizationScheduleRepository;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.asset.entity.FixedAsset;
import com.katasticho.erp.asset.repository.FixedAssetDepreciationRepository;
import com.katasticho.erp.asset.repository.FixedAssetRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.YearMonth;
import java.util.*;

/**
 * Continuous-close agent: for a fiscal period it checks the real status of each
 * close task (drafts posted, depreciation + amortization run, flux reviewed, AI
 * inbox cleared), reports % complete, and gates the period close until ready.
 * Unlike the old one-shot month-close reminder, every item reflects live data.
 */
@Service
@RequiredArgsConstructor
public class ContinuousCloseService {

    private static final Set<String> OPEN = Set.of("PENDING", "DEFERRED");

    private final FiscalPeriodRepository fiscalPeriodRepository;
    private final InvoiceRepository invoiceRepository;
    private final PurchaseBillRepository purchaseBillRepository;
    private final FixedAssetRepository fixedAssetRepository;
    private final FixedAssetDepreciationRepository depreciationRepository;
    private final AmortizationScheduleRepository amortizationScheduleRepository;
    private final AmortizationEntryRepository amortizationEntryRepository;
    private final AiSuggestionRepository aiSuggestionRepository;
    private final FiscalPeriodService fiscalPeriodService;

    @Transactional(readOnly = true)
    public Map<String, Object> checklist(int year, int month) {
        UUID orgId = requireOrgId();
        YearMonth ym = YearMonth.of(year, month);
        LocalDate from = ym.atDay(1);
        LocalDate to = ym.atEndOfMonth();

        Optional<FiscalPeriod> period =
                fiscalPeriodRepository.findByOrgIdAndPeriodYearAndPeriodMonth(orgId, year, month);

        List<Map<String, Object>> items = new ArrayList<>();

        // 1. All invoices posted (no DRAFTs in the period).
        long draftInv = invoiceRepository
                .countByOrgIdAndStatusAndIsDeletedFalseAndInvoiceDateBetween(orgId, "DRAFT", from, to);
        items.add(item("invoices_posted", "All invoices posted",
                draftInv == 0 ? "DONE" : "PENDING",
                draftInv == 0 ? "No draft invoices" : draftInv + " draft invoice(s) to post"));

        // 2. All bills posted.
        long draftBill = purchaseBillRepository
                .countByOrgIdAndStatusAndIsDeletedFalseAndBillDateBetween(orgId, "DRAFT", from, to);
        items.add(item("bills_posted", "All bills posted",
                draftBill == 0 ? "DONE" : "PENDING",
                draftBill == 0 ? "No draft bills" : draftBill + " draft bill(s) to post"));

        // 3. Depreciation run (only if there are active assets in service).
        long activeAssets = fixedAssetRepository
                .findByOrgIdAndStatusAndIsDeletedFalseOrderByAcquisitionDateAsc(orgId, "ACTIVE")
                .stream().filter(a -> !a.getAcquisitionDate().isAfter(to)).count();
        if (activeAssets == 0) {
            items.add(item("depreciation", "Depreciation posted", "NA", "No fixed assets"));
        } else {
            boolean done = depreciationRepository.existsByOrgIdAndPeriodYearAndPeriodMonth(orgId, year, month);
            items.add(item("depreciation", "Depreciation posted", done ? "DONE" : "PENDING",
                    done ? "Posted for the period" : "Run depreciation for " + activeAssets + " asset(s)"));
        }

        // 4. Amortization run (only if schedules are due this period).
        long dueSchedules = amortizationScheduleRepository
                .findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtAsc(orgId, "ACTIVE")
                .stream().filter(s -> dueInPeriod(s, year, month)).count();
        if (dueSchedules == 0) {
            items.add(item("amortization", "Amortization posted", "NA", "No schedules due"));
        } else {
            boolean done = amortizationEntryRepository.existsByOrgIdAndPeriodYearAndPeriodMonth(orgId, year, month);
            items.add(item("amortization", "Amortization posted", done ? "DONE" : "PENDING",
                    done ? "Posted for the period" : "Run amortization for " + dueSchedules + " schedule(s)"));
        }

        // 5. Flux analysis reviewed.
        if (period.isPresent()) {
            boolean openFlux = aiSuggestionRepository.existsOpenSuggestion(
                    orgId, "FISCAL_PERIOD", period.get().getId(), null, "FLUX_ANALYSIS", OPEN);
            items.add(item("flux_reviewed", "Flux analysis reviewed", openFlux ? "PENDING" : "DONE",
                    openFlux ? "Review the flux suggestion in the AI Inbox" : "No pending flux"));
        } else {
            items.add(item("flux_reviewed", "Flux analysis reviewed", "NA", "No fiscal period record"));
        }

        // 6. AI Inbox cleared.
        long pendingInbox = aiSuggestionRepository.countByOrgIdAndStatus(orgId, "PENDING");
        items.add(item("inbox_cleared", "AI Inbox cleared", pendingInbox == 0 ? "DONE" : "PENDING",
                pendingInbox == 0 ? "Nothing pending" : pendingInbox + " item(s) pending"));

        long applicable = items.stream().filter(i -> !"NA".equals(i.get("status"))).count();
        long done = items.stream().filter(i -> "DONE".equals(i.get("status"))).count();
        boolean ready = items.stream().noneMatch(i -> "PENDING".equals(i.get("status")));
        int pct = applicable == 0 ? 100 : (int) Math.round(done * 100.0 / applicable);

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("periodYear", year);
        out.put("periodMonth", month);
        out.put("periodStatus", period.map(FiscalPeriod::getStatus).orElse("ABSENT"));
        out.put("closed", period.map(FiscalPeriod::isClosed).orElse(false));
        out.put("percentComplete", pct);
        out.put("readyToClose", ready);
        out.put("items", items);
        return out;
    }

    /** Close the period — refuses (409) when the checklist isn't green, unless forced. */
    @Transactional
    public Map<String, Object> closeGuarded(int year, int month, boolean force) {
        Map<String, Object> checklist = checklist(year, month);
        boolean ready = Boolean.TRUE.equals(checklist.get("readyToClose"));
        if (!ready && !force) {
            List<?> pending = ((List<?>) checklist.get("items")).stream()
                    .filter(o -> "PENDING".equals(((Map<?, ?>) o).get("status"))).toList();
            throw new BusinessException(
                    "Period is not ready to close — " + pending.size() + " task(s) pending. "
                            + "Resolve them or close with force=true.",
                    "CLOSE_NOT_READY", HttpStatus.CONFLICT);
        }
        fiscalPeriodService.closePeriod(year, month);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("periodYear", year);
        out.put("periodMonth", month);
        out.put("closed", true);
        out.put("forced", !ready);
        return out;
    }

    private static boolean dueInPeriod(AmortizationSchedule s, int year, int month) {
        int start = s.getStartYear() * 12 + (s.getStartMonth() - 1);
        int target = year * 12 + (month - 1);
        int idx = target - start;
        return idx >= 0 && idx < s.getNumberOfPeriods();
    }

    private static Map<String, Object> item(String key, String label, String status, String detail) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("key", key);
        m.put("label", label);
        m.put("status", status);
        m.put("detail", detail);
        return m;
    }

    private static UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
