package com.katasticho.erp.accounting.forex.service;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.forex.dto.ForexRevaluationDtos.RevaluationLine;
import com.katasticho.erp.accounting.forex.dto.ForexRevaluationDtos.RevaluationResult;
import com.katasticho.erp.accounting.forex.dto.ForexRevaluationDtos.RevaluationRunResponse;
import com.katasticho.erp.accounting.forex.entity.ForexRevaluationRun;
import com.katasticho.erp.accounting.forex.repository.ForexRevaluationRunRepository;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.currency.service.CurrencyManagementService;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.MathContext;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Period-end forex revaluation (MASTER_GAP_TRACKER H8). Open foreign-currency AR
 * invoices + AP bills are carried in the books at their transaction-date exchange
 * rate; at period end their base-currency value is restated to the closing rate.
 * The difference is an UNREALIZED forex gain/loss. A single consolidated journal
 * (DR/CR AR, DR/CR AP, balancing Forex Gain/Loss 5500) is posted on the as-of date,
 * plus an auto-reversing journal on the next day — so the settlement-time realized
 * forex (which compares the payment rate against the original invoice rate) is never
 * double-counted. One posted run per (org, as-of date) for idempotency.
 *
 * <p><b>Scope note:</b> revaluation uses each document's CURRENT open balance
 * (documents issued on/before the as-of date that are still open, at their current
 * balanceDue). It does NOT reconstruct the historical open balance as of the date by
 * replaying later payments/credit notes — so run this at or shortly after period end.
 * The next-day auto-reversal confines any residual to the as-of-dated snapshot. Full
 * as-of-date balance reconstruction is a documented follow-up.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ForexRevaluationService {

    /** Forex Gain/Loss account — same literal the realized-forex engine posts to. */
    private static final String FOREX_GAIN_LOSS_CODE = "5500";
    private static final MathContext MC = new MathContext(20, RoundingMode.HALF_UP);

    private final InvoiceRepository invoiceRepository;
    private final PurchaseBillRepository purchaseBillRepository;
    private final OrganisationRepository organisationRepository;
    private final CurrencyManagementService currencyService;
    private final DefaultAccountService defaultAccountService;
    private final JournalService journalService;
    private final ForexRevaluationRunRepository runRepository;

    // ── Public API ────────────────────────────────────────────────────────────

    /** Compute the revaluation WITHOUT posting — the planner-side preview. */
    @Transactional(readOnly = true)
    public RevaluationResult preview(LocalDate asOfDate) {
        UUID orgId = requireOrg();
        requireDate(asOfDate);
        return compute(orgId, baseCurrency(orgId), asOfDate);
    }

    /** Run the revaluation: post the consolidated journal + its next-day reversal, record the run. */
    @Transactional
    public RevaluationRunResponse revalue(LocalDate asOfDate) {
        UUID orgId = requireOrg();
        requireDate(asOfDate);
        runRepository.findByOrgIdAndAsOfDate(orgId, asOfDate).ifPresent(r -> {
            throw new BusinessException(
                    "Forex revaluation has already been run for " + asOfDate,
                    "FOREX_REVAL_ALREADY_RUN", HttpStatus.CONFLICT);
        });

        String base = baseCurrency(orgId);
        RevaluationResult result = compute(orgId, base, asOfDate);

        // A zero-delta run posts nothing — do NOT record/lock the (org, as-of date), so a
        // later real run (e.g. once the closing rates are actually entered) can still proceed.
        // Only a run that posts a journal is recorded, and that recording is what blocks a
        // duplicate post for the same date.
        if (result.arDelta().signum() == 0 && result.apDelta().signum() == 0) {
            log.info("Forex revaluation {} for org {}: nothing to revalue ({} docs) — no run recorded",
                    asOfDate, orgId, result.revaluedDocumentCount());
            return new RevaluationRunResponse(null, asOfDate, base,
                    BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO,
                    result.revaluedDocumentCount(), null, null);
        }

        ForexRevaluationRun run = runRepository.save(ForexRevaluationRun.builder()
                .orgId(orgId).asOfDate(asOfDate).baseCurrency(base)
                .arDelta(result.arDelta()).apDelta(result.apDelta())
                .netGainLoss(result.netGainLoss())
                .revaluedDocumentCount(result.revaluedDocumentCount())
                .createdBy(TenantContext.getCurrentUserId())
                .build());

        JournalEntry reval = journalService.postJournal(
                buildRequest(result, asOfDate, false, run.getId()));
        JournalEntry reversal = journalService.postJournal(
                buildRequest(result, asOfDate.plusDays(1), true, run.getId()));
        run.setRevalJournalEntryId(reval.getId());
        run.setReversalJournalEntryId(reversal.getId());
        run = runRepository.save(run);

        log.info("Forex revaluation {} for org {}: {} docs, net {} {}",
                asOfDate, orgId, result.revaluedDocumentCount(), result.netGainLoss(), base);
        return toResponse(run);
    }

    @Transactional(readOnly = true)
    public List<RevaluationRunResponse> listRuns() {
        return runRepository.findByOrgIdOrderByAsOfDateDesc(requireOrg())
                .stream().map(this::toResponse).toList();
    }

    // ── Core computation ────────────────────────────────────────────────────────

    private RevaluationResult compute(UUID orgId, String base, LocalDate asOfDate) {
        List<RevaluationLine> lines = new ArrayList<>();
        List<String> warnings = new ArrayList<>();
        BigDecimal arDelta = BigDecimal.ZERO;
        BigDecimal apDelta = BigDecimal.ZERO;

        for (Invoice inv : invoiceRepository.findOutstandingInvoices(orgId)) {
            RevalComputed c = revalue(base, asOfDate, "AR", inv.getId(), inv.getInvoiceNumber(),
                    inv.getCurrency(), inv.getBalanceDue(), inv.getExchangeRate(),
                    inv.getInvoiceDate(), warnings);
            if (c != null) {
                arDelta = arDelta.add(c.delta());
                lines.add(c.line());
            }
        }
        for (PurchaseBill bill : purchaseBillRepository.findOutstandingBills(orgId)) {
            RevalComputed c = revalue(base, asOfDate, "AP", bill.getId(), bill.getBillNumber(),
                    bill.getCurrency(), bill.getBalanceDue(), bill.getExchangeRate(),
                    bill.getBillDate(), warnings);
            if (c != null) {
                apDelta = apDelta.add(c.delta());
                lines.add(c.line());
            }
        }
        BigDecimal netGainLoss = arDelta.subtract(apDelta);
        return new RevaluationResult(asOfDate, base, arDelta, apDelta, netGainLoss,
                lines.size(), lines, warnings);
    }

    private record RevalComputed(BigDecimal delta, RevaluationLine line) {}

    /** Revalue a single open document; returns null (with an optional warning) when it can't be revalued. */
    private RevalComputed revalue(String base, LocalDate asOfDate, String side, UUID docId,
                                  String docNumber, String currency, BigDecimal balanceDue,
                                  BigDecimal bookRate, LocalDate docDate, List<String> warnings) {
        if (currency == null || currency.equalsIgnoreCase(base)) {
            return null; // base-currency document — nothing to revalue
        }
        if (docDate != null && docDate.isAfter(asOfDate)) {
            return null; // issued after the revaluation date
        }
        if (balanceDue == null || balanceDue.signum() <= 0) {
            return null;
        }
        if (bookRate == null || bookRate.signum() <= 0) {
            warnings.add(side + " " + docNumber + " skipped: no book exchange rate on the document");
            return null;
        }
        BigDecimal closingRate;
        try {
            closingRate = currencyService.getExchangeRate(currency, base, asOfDate);
        } catch (RuntimeException e) {
            warnings.add(side + " " + docNumber + " (" + currency + ") skipped: no closing rate as of " + asOfDate);
            return null;
        }
        if (closingRate == null || closingRate.signum() <= 0) {
            warnings.add(side + " " + docNumber + " (" + currency + ") skipped: closing rate not positive");
            return null;
        }
        BigDecimal bookBase = balanceDue.multiply(bookRate, MC).setScale(2, RoundingMode.HALF_UP);
        BigDecimal closingBase = balanceDue.multiply(closingRate, MC).setScale(2, RoundingMode.HALF_UP);
        BigDecimal delta = closingBase.subtract(bookBase);
        if (delta.signum() == 0) {
            return null; // rate unchanged for this document — nothing to post
        }
        return new RevalComputed(delta, new RevaluationLine(side, docId, docNumber, currency,
                balanceDue, bookRate, closingRate, bookBase, closingBase, delta));
    }

    // ── Journal building ────────────────────────────────────────────────────────

    private JournalPostRequest buildRequest(RevaluationResult r, LocalDate date, boolean reverse, UUID runId) {
        BigDecimal ar = reverse ? r.arDelta().negate() : r.arDelta();
        BigDecimal ap = reverse ? r.apDelta().negate() : r.apDelta();
        BigDecimal net = ar.subtract(ap); // gain when positive

        UUID orgId = requireOrg();
        String arCode = defaultAccountService.get(orgId, DefaultAccountPurpose.AR).getCode();
        String apCode = defaultAccountService.get(orgId, DefaultAccountPurpose.AP).getCode();
        List<JournalLineRequest> lines = new ArrayList<>();
        String suffix = " as of " + r.asOfDate() + (reverse ? " (reversal)" : "");

        // AR is an asset: a positive delta (receivable worth more in base) is a debit.
        if (ar.signum() != 0) {
            lines.add(new JournalLineRequest(arCode, pos(ar), neg(ar),
                    "AR forex revaluation" + suffix, null, null));
        }
        // AP is a liability: a positive delta (payable worth more in base) is a credit.
        if (ap.signum() != 0) {
            lines.add(new JournalLineRequest(apCode, neg(ap), pos(ap),
                    "AP forex revaluation" + suffix, null, null));
        }
        // Forex Gain/Loss balancer: net gain (>0) is a credit (income); net loss is a debit.
        if (net.signum() != 0) {
            lines.add(new JournalLineRequest(FOREX_GAIN_LOSS_CODE, neg(net), pos(net),
                    (net.signum() > 0 ? "Unrealized forex gain" : "Unrealized forex loss") + suffix,
                    null, null));
        }
        return new JournalPostRequest(date, "Period-end forex revaluation" + suffix,
                "FOREX_REVAL", runId, lines, true);
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    private static BigDecimal pos(BigDecimal v) {
        return v.signum() > 0 ? v : BigDecimal.ZERO;
    }

    private static BigDecimal neg(BigDecimal v) {
        return v.signum() < 0 ? v.negate() : BigDecimal.ZERO;
    }

    private String baseCurrency(UUID orgId) {
        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));
        return org.getBaseCurrency();
    }

    private RevaluationRunResponse toResponse(ForexRevaluationRun run) {
        return new RevaluationRunResponse(run.getId(), run.getAsOfDate(), run.getBaseCurrency(),
                run.getArDelta(), run.getApDelta(), run.getNetGainLoss(),
                run.getRevaluedDocumentCount(), run.getRevalJournalEntryId(),
                run.getReversalJournalEntryId());
    }

    private void requireDate(LocalDate asOfDate) {
        if (asOfDate == null) {
            throw new BusinessException("As-of date is required", "FOREX_REVAL_DATE_REQUIRED", HttpStatus.BAD_REQUEST);
        }
    }

    private UUID requireOrg() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
