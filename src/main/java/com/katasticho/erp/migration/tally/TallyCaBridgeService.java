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
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.migration.tally.TallyImportDtos.TallyTbLine;
import com.katasticho.erp.migration.tally.TallyImportDtos.TbVerificationLine;
import com.katasticho.erp.migration.tally.TallyImportDtos.TbVerificationResult;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Pageable;
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
    private final ContactRepository contactRepository;
    private final ItemRepository itemRepository;

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

    // ── Tally XML masters export ────────────────────────────────────────────

    /**
     * Export org masters (accounts, contacts, items) as Tally-importable XML.
     *
     * <ul>
     *   <li><b>Accounts</b> → {@code <LEDGER>} elements under the closest Tally group
     *       (Sundry Debtors / Sundry Creditors / Capital Account / Indirect Expenses /
     *        Indirect Income / Current Liabilities / Current Assets).</li>
     *   <li><b>Contacts</b> → {@code <LEDGER>} elements under Sundry Debtors (CUSTOMER)
     *       or Sundry Creditors (VENDOR).</li>
     *   <li><b>Items</b> → {@code <STOCKITEM>} elements with rate and unit of measure.</li>
     * </ul>
     *
     * Import into TallyPrime: Gateway → Import Data → Masters.
     */
    @Transactional(readOnly = true)
    public String exportMastersXml() {
        UUID orgId = requireOrgId();

        List<Account> accounts = accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId);
        List<Contact> contacts = contactRepository.findByOrgIdAndIsDeletedFalse(orgId, Pageable.unpaged()).getContent();
        List<Item> items = itemRepository.findByOrgIdAndIsDeletedFalseAndTrackInventoryTrue(orgId);

        StringBuilder xml = new StringBuilder(8192);
        xml.append("<ENVELOPE>\n")
                .append(" <HEADER>\n")
                .append("  <TALLYREQUEST>Import Data</TALLYREQUEST>\n")
                .append(" </HEADER>\n")
                .append(" <BODY>\n")
                .append("  <IMPORTDATA>\n")
                .append("   <REQUESTDESC>\n")
                .append("    <REPORTNAME>All Masters</REPORTNAME>\n")
                .append("   </REQUESTDESC>\n")
                .append("   <REQUESTDATA>\n");

        // ── Accounts → Ledgers ──────────────────────────────────────────────
        for (Account a : accounts) {
            if (a.isSystem()) continue;  // skip auto-created system accounts
            String group = tallyGroupFor(a.getType(), a.getSubType());
            xml.append("    <TALLYMESSAGE xmlns:UDF=\"TallyUDF\">\n")
                    .append("     <LEDGER NAME=\"").append(xmlAttr(a.getName()))
                    .append("\" ACTION=\"Create\">\n")
                    .append("      <NAME>").append(xmlText(a.getName())).append("</NAME>\n")
                    .append("      <PARENT>").append(xmlText(group)).append("</PARENT>\n");
            if (a.getOpeningBalance() != null && a.getOpeningBalance().signum() != 0) {
                // Positive opening = debit for asset/expense accounts; Tally uses same convention.
                xml.append("      <OPENINGBALANCE>")
                        .append(a.getOpeningBalance().toPlainString())
                        .append("</OPENINGBALANCE>\n");
            }
            if (a.getDescription() != null && !a.getDescription().isBlank()) {
                xml.append("      <NARRATION>").append(xmlText(a.getDescription())).append("</NARRATION>\n");
            }
            xml.append("     </LEDGER>\n")
                    .append("    </TALLYMESSAGE>\n");
        }

        // ── Contacts → Ledgers (Sundry Debtors / Creditors) ────────────────
        for (Contact c : contacts) {
            ContactType type = c.getContactType();
            String group = ContactType.VENDOR == type ? "Sundry Creditors" : "Sundry Debtors";
            xml.append("    <TALLYMESSAGE xmlns:UDF=\"TallyUDF\">\n")
                    .append("     <LEDGER NAME=\"").append(xmlAttr(c.getDisplayName()))
                    .append("\" ACTION=\"Create\">\n")
                    .append("      <NAME>").append(xmlText(c.getDisplayName())).append("</NAME>\n")
                    .append("      <PARENT>").append(xmlText(group)).append("</PARENT>\n");
            if (c.getGstin() != null && !c.getGstin().isBlank()) {
                xml.append("      <GSTIN>").append(xmlText(c.getGstin())).append("</GSTIN>\n");
            }
            xml.append("     </LEDGER>\n")
                    .append("    </TALLYMESSAGE>\n");
        }

        // ── Items → Stock Items ─────────────────────────────────────────────
        for (Item item : items) {
            xml.append("    <TALLYMESSAGE xmlns:UDF=\"TallyUDF\">\n")
                    .append("     <STOCKITEM NAME=\"").append(xmlAttr(item.getName()))
                    .append("\" ACTION=\"Create\">\n")
                    .append("      <NAME>").append(xmlText(item.getName())).append("</NAME>\n")
                    .append("      <BASEUNITS>").append(xmlText(item.getUnitOfMeasure())).append("</BASEUNITS>\n");
            if (item.getHsnCode() != null && !item.getHsnCode().isBlank()) {
                xml.append("      <HSNCODE>").append(xmlText(item.getHsnCode())).append("</HSNCODE>\n");
            }
            if (item.getPurchasePrice() != null && item.getPurchasePrice().signum() != 0) {
                xml.append("      <COSTPRICE>").append(item.getPurchasePrice().toPlainString())
                        .append("</COSTPRICE>\n");
            }
            if (item.getSalePrice() != null && item.getSalePrice().signum() != 0) {
                xml.append("      <SELLINGPRICE>").append(item.getSalePrice().toPlainString())
                        .append("</SELLINGPRICE>\n");
            }
            xml.append("     </STOCKITEM>\n")
                    .append("    </TALLYMESSAGE>\n");
        }

        xml.append("   </REQUESTDATA>\n")
                .append("  </IMPORTDATA>\n")
                .append(" </BODY>\n")
                .append("</ENVELOPE>\n");

        log.info("Tally masters XML export: {} accounts, {} contacts, {} items",
                accounts.stream().filter(a -> !a.isSystem()).count(), contacts.size(), items.size());
        return xml.toString();
    }

    /**
     * Map our account type/subtype to the closest standard Tally group name.
     * Tally's built-in groups: Capital Account, Loans (Liability), Current Liabilities,
     * Sundry Creditors, Sundry Debtors, Current Assets, Bank Accounts,
     * Fixed Assets, Indirect Expenses, Indirect Income, Sales Accounts, Purchase Accounts.
     */
    static String tallyGroupFor(String type, String subType) {
        if (type == null) return "Indirect Expenses";
        String t = type.toUpperCase(Locale.ROOT);
        String s = subType != null ? subType.toUpperCase(Locale.ROOT) : "";
        return switch (t) {
            case "ASSET" -> {
                if (s.contains("BANK")) yield "Bank Accounts";
                if (s.contains("CASH")) yield "Cash-in-Hand";
                if (s.contains("RECEIVABLE") || s.contains("DEBTOR")) yield "Sundry Debtors";
                if (s.contains("FIXED") || s.contains("EQUIPMENT")) yield "Fixed Assets";
                if (s.contains("INVENTORY") || s.contains("STOCK")) yield "Stock-in-Hand";
                yield "Current Assets";
            }
            case "LIABILITY" -> {
                if (s.contains("CREDITOR") || s.contains("PAYABLE") && s.contains("VENDOR")) yield "Sundry Creditors";
                if (s.contains("CAPITAL") || s.contains("EQUITY")) yield "Capital Account";
                if (s.contains("LOAN")) yield "Loans (Liability)";
                yield "Current Liabilities";
            }
            case "EQUITY" -> "Capital Account";
            case "INCOME", "REVENUE" -> s.contains("SALES") ? "Sales Accounts" : "Indirect Income";
            case "EXPENSE", "COGS" -> s.contains("PURCHASE") ? "Purchase Accounts" : "Indirect Expenses";
            default -> "Indirect Expenses";
        };
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
