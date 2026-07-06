package com.katasticho.erp.accounting.service;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.repository.JournalEntryRepository;
import com.katasticho.erp.accounting.repository.JournalLineRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Year-end closing entry — zeroes every P&L (REVENUE / EXPENSE) account for a
 * fiscal year into Retained Earnings (3020). Profit credits RE, loss debits it,
 * so after the close the year's P&L reads flat and net income lands in equity.
 *
 * <p>The closing journal posts to the FY's last day. It's idempotent per
 * (org, fiscalYear): a deterministic {@code sourceId} marker blocks a second
 * close (a reversal of the close entry re-opens the year). The double-entry is
 * balanced by construction — total debits always equal total credits.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class YearEndCloseService {

    static final String SOURCE_MODULE = "YEAR_END_CLOSE";

    private final OrganisationRepository organisationRepository;
    private final AccountRepository accountRepository;
    private final JournalLineRepository journalLineRepository;
    private final JournalEntryRepository journalEntryRepository;
    private final JournalService journalService;
    private final DefaultAccountService defaultAccountService;

    @Transactional
    public CloseResult closeYear(int fiscalYear) {
        UUID orgId = TenantContext.getCurrentOrgId();
        // Pessimistic org-row lock held for the whole transaction so two concurrent
        // closes serialise: the first posts + commits, the second re-reads the
        // just-posted close and throws YEAR_END_ALREADY_CLOSED instead of both
        // posting a full closing journal (which would double Retained Earnings).
        Organisation org = organisationRepository.findByIdForUpdate(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        int fyStart = org.getFiscalYearStart() != null ? org.getFiscalYearStart() : 4;
        LocalDate start = LocalDate.of(fiscalYear, fyStart, 1);
        LocalDate end = start.plusYears(1).minusDays(1);

        UUID closeId = closeId(orgId, fiscalYear);

        // Idempotency: an existing LIVE close entry (posted, not reversed, and not
        // itself a reversal) blocks a re-close. Excluding is_reversal is essential —
        // after a reopen the reversal entry is POSTED but must not count as a live
        // close, or the year could never be re-closed.
        boolean alreadyClosed = journalEntryRepository
                .findBySourceModuleAndSourceIdAndStatus(SOURCE_MODULE, closeId, "POSTED")
                .stream().anyMatch(e -> !e.isReversed() && !e.isReversal());
        if (alreadyClosed) {
            throw new BusinessException("Fiscal year " + fiscalYear + " is already closed",
                    "YEAR_END_ALREADY_CLOSED", HttpStatus.CONFLICT);
        }

        // Per-account net (debit − credit) of every posted line in the FY.
        Map<UUID, BigDecimal> netByAccount = new HashMap<>();
        for (Object[] row : journalLineRepository.computeAccountTotalsForPeriod(orgId, start, end)) {
            UUID accountId = (UUID) row[0];
            BigDecimal debit = (BigDecimal) row[1];
            BigDecimal credit = (BigDecimal) row[2];
            netByAccount.put(accountId, debit.subtract(credit));
        }

        List<Account> accounts = accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId);
        List<JournalLineRequest> lines = new ArrayList<>();
        BigDecimal totalPlNet = BigDecimal.ZERO;

        for (Account acct : accounts) {
            String type = acct.getType();
            if (!"REVENUE".equals(type) && !"EXPENSE".equals(type)) continue;
            BigDecimal net = netByAccount.getOrDefault(acct.getId(), BigDecimal.ZERO);
            if (net.signum() == 0) continue;
            totalPlNet = totalPlNet.add(net);
            // Post the reverse of the account's net so the account zeroes out.
            if (net.signum() > 0) {
                lines.add(closeLine(acct.getCode(), BigDecimal.ZERO, net));      // debit-balance → credit it
            } else {
                lines.add(closeLine(acct.getCode(), net.negate(), BigDecimal.ZERO)); // credit-balance → debit it
            }
        }

        if (lines.isEmpty()) {
            // No P&L activity in the year — nothing to close.
            log.info("Year-end close FY{} for org {}: no P&L activity, nothing to post",
                    fiscalYear, orgId);
            return new CloseResult(fiscalYear, start, end, BigDecimal.ZERO, 0, null);
        }

        // Net income = revenues − expenses = −totalPlNet. The RE line balances it.
        BigDecimal netIncome = totalPlNet.negate();
        String reCode = defaultAccountService.getCode(orgId, DefaultAccountPurpose.RETAINED_EARNINGS);
        if (totalPlNet.signum() > 0) {
            lines.add(closeLine(reCode, totalPlNet, BigDecimal.ZERO));            // net loss → debit RE
        } else {
            lines.add(closeLine(reCode, BigDecimal.ZERO, totalPlNet.negate()));   // net profit → credit RE
        }

        JournalPostRequest request = new JournalPostRequest(
                end,
                "Year-end closing — FY " + fiscalYear,
                SOURCE_MODULE,
                closeId,
                lines,
                true);
        JournalEntry entry = journalService.postJournal(request);

        log.info("Year-end close FY{} org {}: closed {} P&L account(s), net income {}, entry {}",
                fiscalYear, orgId, lines.size() - 1, netIncome, entry.getEntryNumber());

        return new CloseResult(fiscalYear, start, end, netIncome, lines.size() - 1, entry.getId());
    }

    /**
     * Reopen a closed fiscal year by reversing its close entry IN-PERIOD (dated the
     * FY's last day) so the reversal nets the close lines within the same year —
     * P&L accounts return to their pre-close balances and Retained Earnings is
     * restored. Reversing the close via the generic current-dated path instead would
     * post phantom P&L into the CURRENT year and zero out RE (cross-year corruption).
     * After a reopen closeYear can legitimately re-run (the reversal is is_reversal,
     * so the idempotency guard no longer sees a live close).
     */
    @Transactional
    public JournalEntry reopenYear(int fiscalYear) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID closeId = closeId(orgId, fiscalYear);
        JournalEntry live = journalEntryRepository
                .findBySourceModuleAndSourceIdAndStatus(SOURCE_MODULE, closeId, "POSTED")
                .stream().filter(e -> !e.isReversed() && !e.isReversal())
                .findFirst()
                .orElseThrow(() -> new BusinessException(
                        "Fiscal year " + fiscalYear + " is not closed",
                        "YEAR_END_NOT_CLOSED", HttpStatus.BAD_REQUEST));
        JournalEntry reversal = journalService.reverseEntry(live.getId(), live.getEffectiveDate());
        log.info("Year-end close FY{} org {} reopened via reversal {}",
                fiscalYear, orgId, reversal.getEntryNumber());
        return reversal;
    }

    /** Deterministic per (org, fiscalYear) so a re-close is detectable. */
    static UUID closeId(UUID orgId, int fiscalYear) {
        return UUID.nameUUIDFromBytes(
                ("YEC:" + orgId + ":" + fiscalYear).getBytes(StandardCharsets.UTF_8));
    }

    private JournalLineRequest closeLine(String code, BigDecimal debit, BigDecimal credit) {
        return new JournalLineRequest(code, debit, credit, "Year-end close", null, null);
    }

    public record CloseResult(int fiscalYear, LocalDate periodStart, LocalDate periodEnd,
                              BigDecimal netIncome, int plAccountsClosed, UUID journalEntryId) {}
}
