package com.katasticho.erp.migration.tally;

import com.katasticho.erp.accounting.dto.report.TrialBalanceResponse;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.entity.JournalLine;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.repository.JournalEntryRepository;
import com.katasticho.erp.accounting.service.FinancialReportService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.migration.tally.TallyImportDtos.TallyTbLine;
import com.katasticho.erp.migration.tally.TallyImportDtos.TbVerificationLine;
import com.katasticho.erp.migration.tally.TallyImportDtos.TbVerificationResult;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * Tally → Katasticho migration, slice 3: the "CA Bridge" — the trust layer that
 * lets a customer switch while their CA keeps Tally.
 *
 * <ul>
 *   <li><b>Trial Balance verification:</b> upload the closing TB exported from
 *       Tally and diff it against our books, account by account. The CA signs
 *       off the migration in minutes instead of re-keying.</li>
 *   <li><b>Tally XML voucher export:</b> our posted journals for a period,
 *       written back in Tally-importable XML so the CA continues filing from
 *       Tally untouched. This is the mirror image of the Day Book importer —
 *       same sign convention, reversed.</li>
 * </ul>
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class TallyCaBridgeService {

    private final TallyXmlParser parser;
    private final FinancialReportService financialReportService;
    private final JournalEntryRepository journalEntryRepository;
    private final AccountRepository accountRepository;

    /** Names matched within this rupee tolerance are treated as equal. */
    private static final BigDecimal TOLERANCE = BigDecimal.ONE;

    private static final DateTimeFormatter TALLY_DATE = DateTimeFormatter.ofPattern("yyyyMMdd");

    // ── Trial Balance verification ──────────────────────────────────────

    public TbVerificationResult verifyTrialBalance(byte[] tallyTbXml, LocalDate asOfDate) {
        requireOrgId();
        LocalDate as = asOfDate != null ? asOfDate : LocalDate.now();

        TrialBalanceResponse ours = financialReportService.generateTrialBalance(as);
        List<TallyTbLine> tally = parser.parseTrialBalance(tallyTbXml);

        // Our balances by normalized name (signed: + debit, − credit).
        Map<String, BigDecimal> ourByName = new LinkedHashMap<>();
        Map<String, String> ourDisplay = new HashMap<>();
        BigDecimal ourTotalDebit = BigDecimal.ZERO, ourTotalCredit = BigDecimal.ZERO;
        for (TrialBalanceResponse.TrialBalanceLine l : ours.lines()) {
            String key = norm(l.accountName());
            ourByName.merge(key, l.balance(), BigDecimal::add);
            ourDisplay.putIfAbsent(key, l.accountName());
            ourTotalDebit = ourTotalDebit.add(nz(l.debit()));
            ourTotalCredit = ourTotalCredit.add(nz(l.credit()));
        }

        // Tally balances by normalized name (signed).
        Map<String, BigDecimal> tallyByName = new LinkedHashMap<>();
        Map<String, String> tallyDisplay = new HashMap<>();
        BigDecimal tallyTotalDebit = BigDecimal.ZERO, tallyTotalCredit = BigDecimal.ZERO;
        for (TallyTbLine l : tally) {
            String key = norm(l.ledgerName());
            tallyByName.merge(key, nz(l.debit()).subtract(nz(l.credit())), BigDecimal::add);
            tallyDisplay.putIfAbsent(key, l.ledgerName());
            tallyTotalDebit = tallyTotalDebit.add(nz(l.debit()));
            tallyTotalCredit = tallyTotalCredit.add(nz(l.credit()));
        }

        Set<String> allKeys = new LinkedHashSet<>();
        allKeys.addAll(tallyByName.keySet());
        allKeys.addAll(ourByName.keySet());

        List<TbVerificationLine> lines = new ArrayList<>();
        int matched = 0, mismatched = 0, missingInBooks = 0, missingInTally = 0;

        for (String key : allKeys) {
            BigDecimal ourBal = ourByName.get(key);
            BigDecimal tallyBal = tallyByName.get(key);
            String display = tallyDisplay.getOrDefault(key, ourDisplay.get(key));

            String status;
            BigDecimal diff;
            if (ourBal == null) {
                status = "MISSING_IN_BOOKS";
                diff = tallyBal.negate();
                missingInBooks++;
            } else if (tallyBal == null) {
                status = "MISSING_IN_TALLY";
                diff = ourBal;
                missingInTally++;
            } else {
                diff = ourBal.subtract(tallyBal);
                if (diff.abs().compareTo(TOLERANCE) <= 0) {
                    status = "MATCHED";
                    matched++;
                } else {
                    status = "MISMATCH";
                    mismatched++;
                }
            }
            lines.add(new TbVerificationLine(display, ourBal, tallyBal, diff, status));
        }

        // Sort: problems first (mismatch, missing), then matched.
        lines.sort(Comparator.comparingInt(l -> switch (l.status()) {
            case "MISMATCH" -> 0;
            case "MISSING_IN_BOOKS" -> 1;
            case "MISSING_IN_TALLY" -> 2;
            default -> 3;
        }));

        boolean balancesMatch = ourTotalDebit.subtract(tallyTotalDebit).abs().compareTo(TOLERANCE) <= 0
                && ourTotalCredit.subtract(tallyTotalCredit).abs().compareTo(TOLERANCE) <= 0;

        log.info("Tally TB verification @ {}: {} matched, {} mismatch, {} missing-in-books, {} missing-in-tally",
                as, matched, mismatched, missingInBooks, missingInTally);

        return new TbVerificationResult(as.toString(), matched, mismatched, missingInBooks,
                missingInTally, balancesMatch, ourTotalDebit, ourTotalCredit,
                tallyTotalDebit, tallyTotalCredit, lines);
    }

    // ── Tally XML voucher export ────────────────────────────────────────

    @Transactional(readOnly = true)
    public String exportVouchersXml(LocalDate from, LocalDate to) {
        UUID orgId = requireOrgId();
        if (from == null || to == null) {
            throw new BusinessException("fromDate and toDate are required",
                    "TALLY_EXPORT_RANGE_REQUIRED");
        }
        if (from.isAfter(to)) {
            throw new BusinessException("fromDate must not be after toDate",
                    "TALLY_EXPORT_RANGE_INVALID");
        }

        List<JournalEntry> entries = journalEntryRepository.findPostedWithLinesInRange(orgId, from, to);

        Map<UUID, String> accountNames = new HashMap<>();
        for (Account a : accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId)) {
            accountNames.put(a.getId(), a.getName());
        }

        StringBuilder xml = new StringBuilder(4096);
        xml.append("<ENVELOPE>\n")
                .append(" <HEADER>\n")
                .append("  <TALLYREQUEST>Import Data</TALLYREQUEST>\n")
                .append(" </HEADER>\n")
                .append(" <BODY>\n")
                .append("  <IMPORTDATA>\n")
                .append("   <REQUESTDESC>\n")
                .append("    <REPORTNAME>Vouchers</REPORTNAME>\n")
                .append("   </REQUESTDESC>\n")
                .append("   <REQUESTDATA>\n");

        for (JournalEntry e : entries) {
            String vchType = voucherTypeFor(e.getSourceModule());
            xml.append("    <TALLYMESSAGE xmlns:UDF=\"TallyUDF\">\n")
                    .append("     <VOUCHER VCHTYPE=\"").append(xmlAttr(vchType))
                    .append("\" ACTION=\"Create\" OBJVIEW=\"Accounting Voucher View\">\n")
                    .append("      <DATE>").append(e.getEffectiveDate().format(TALLY_DATE)).append("</DATE>\n")
                    .append("      <VOUCHERTYPENAME>").append(xmlText(vchType)).append("</VOUCHERTYPENAME>\n");
            if (e.getEntryNumber() != null) {
                xml.append("      <VOUCHERNUMBER>").append(xmlText(e.getEntryNumber())).append("</VOUCHERNUMBER>\n");
            }
            if (e.getDescription() != null && !e.getDescription().isBlank()) {
                xml.append("      <NARRATION>").append(xmlText(e.getDescription())).append("</NARRATION>\n");
            }

            for (JournalLine line : e.getLines()) {
                String ledger = accountNames.getOrDefault(line.getAccountId(), "Suspense A/c");
                BigDecimal debit = nz(line.getBaseDebit());
                BigDecimal credit = nz(line.getBaseCredit());
                boolean isDebit = debit.signum() != 0;
                // Tally: debit = NEGATIVE amount + ISDEEMEDPOSITIVE Yes; credit = positive + No.
                BigDecimal magnitude = isDebit ? debit : credit;
                String amount = (isDebit ? magnitude.negate() : magnitude).toPlainString();
                xml.append("      <ALLLEDGERENTRIES.LIST>\n")
                        .append("       <LEDGERNAME>").append(xmlText(ledger)).append("</LEDGERNAME>\n")
                        .append("       <ISDEEMEDPOSITIVE>").append(isDebit ? "Yes" : "No")
                        .append("</ISDEEMEDPOSITIVE>\n")
                        .append("       <AMOUNT>").append(amount).append("</AMOUNT>\n")
                        .append("      </ALLLEDGERENTRIES.LIST>\n");
            }

            xml.append("     </VOUCHER>\n")
                    .append("    </TALLYMESSAGE>\n");
        }

        xml.append("   </REQUESTDATA>\n")
                .append("  </IMPORTDATA>\n")
                .append(" </BODY>\n")
                .append("</ENVELOPE>\n");

        log.info("Tally XML export: {} vouchers from {} to {}", entries.size(), from, to);
        return xml.toString();
    }

    /** Map our source module to the closest TallyPrime voucher type. */
    static String voucherTypeFor(String sourceModule) {
        if (sourceModule == null) return "Journal";
        String m = sourceModule.toUpperCase(Locale.ROOT);
        if (m.contains("RECEIPT")) return "Receipt";
        if (m.contains("PAYMENT")) return "Payment";
        if (m.contains("POS")) return "Receipt";
        if (m.contains("SALES") || m.contains("INVOICE")) return "Sales";
        if (m.contains("PURCHASE") || m.contains("BILL")) return "Purchase";
        if (m.contains("CONTRA")) return "Contra";
        if (m.contains("CREDIT")) return "Credit Note";
        if (m.contains("DEBIT")) return "Debit Note";
        return "Journal";
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private static String norm(String s) {
        return s == null ? "" : s.trim().toLowerCase(Locale.ROOT);
    }

    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }

    private static String xmlText(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
    }

    private static String xmlAttr(String s) {
        return xmlText(s).replace("\"", "&quot;");
    }

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
