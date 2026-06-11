package com.katasticho.erp.migration.tally;

import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.migration.tally.TallyImportDtos.RowError;
import com.katasticho.erp.migration.tally.TallyImportDtos.VoucherImportPreview;
import com.katasticho.erp.migration.tally.TallyImportDtos.VoucherImportResult;
import com.katasticho.erp.migration.tally.TallyImportDtos.VoucherPlan;
import com.katasticho.erp.migration.tally.TallyVoucher.LedgerEntry;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.*;

/**
 * Tally → Katasticho migration, slice 2: Day Book vouchers.
 *
 * <p>Every Tally voucher (Sales, Purchase, Receipt, Payment, Journal, Contra,
 * Debit Note, Credit Note, etc.) is imported as a <b>journal entry</b> via
 * {@link JournalService}. This is safe — no stock movements, no domain events,
 * no payment allocations — just accounting history that makes the trial balance
 * match Tally's.
 *
 * <p>Ledger resolution: each ledger name in a voucher is resolved to a chart-of-
 * accounts code. The lookup order is:
 * <ol>
 *   <li>Contact (customer → AR 1100, vendor → AP 2010)</li>
 *   <li>Account by name (covers Slice 1 masters import)</li>
 *   <li>Well-known Tally ledger name patterns (Cash, Bank, Sales, Purchase, GST)</li>
 * </ol>
 *
 * <p>Two-phase: {@link #preview} is read-only; {@link #importVouchers} commits.
 * Re-running is handled by the caller (duplicate vouchers create duplicate
 * journals — the preview warns about this).
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class TallyVoucherImportService {

    private final TallyXmlParser parser;
    private final ContactRepository contactRepository;
    private final AccountRepository accountRepository;
    private final JournalService journalService;

    // ── Well-known Tally ledger → account code mappings ─────────────────

    private static final Map<String, String> WELL_KNOWN = new LinkedHashMap<>();
    static {
        WELL_KNOWN.put("cash", "1010");
        WELL_KNOWN.put("cash a/c", "1010");
        WELL_KNOWN.put("cash-in-hand", "1010");
        WELL_KNOWN.put("cash in hand", "1010");
        WELL_KNOWN.put("petty cash", "1010");
        WELL_KNOWN.put("sales", "4010");
        WELL_KNOWN.put("sales a/c", "4010");
        WELL_KNOWN.put("sales account", "4010");
        WELL_KNOWN.put("purchase", "5020");
        WELL_KNOWN.put("purchase a/c", "5020");
        WELL_KNOWN.put("purchase account", "5020");
        WELL_KNOWN.put("cgst", "2020");
        WELL_KNOWN.put("output cgst", "2020");
        WELL_KNOWN.put("cgst payable", "2020");
        WELL_KNOWN.put("central gst", "2020");
        WELL_KNOWN.put("sgst", "2021");
        WELL_KNOWN.put("output sgst", "2021");
        WELL_KNOWN.put("sgst payable", "2021");
        WELL_KNOWN.put("state gst", "2021");
        WELL_KNOWN.put("igst", "2022");
        WELL_KNOWN.put("output igst", "2022");
        WELL_KNOWN.put("igst payable", "2022");
        WELL_KNOWN.put("integrated gst", "2022");
        WELL_KNOWN.put("input cgst", "1500");
        WELL_KNOWN.put("input sgst", "1500");
        WELL_KNOWN.put("input igst", "1500");
        WELL_KNOWN.put("gst input credit", "1500");
        WELL_KNOWN.put("tds payable", "2030");
        WELL_KNOWN.put("tds", "2030");
        WELL_KNOWN.put("round off", "5600");
        WELL_KNOWN.put("rounding off", "5600");
        WELL_KNOWN.put("discount allowed", "5290");
        WELL_KNOWN.put("discount given", "5290");
        WELL_KNOWN.put("discount received", "4120");
        WELL_KNOWN.put("bank charges", "5280");
    }

    // ── Public API ───────────────────────────────────────────────────────

    public VoucherImportPreview preview(byte[] xml) {
        UUID orgId = requireOrgId();
        List<TallyVoucher> vouchers = parser.parseVouchers(xml);
        List<VoucherPlan> plans = new ArrayList<>(vouchers.size());
        Map<String, Integer> byType = new LinkedHashMap<>();
        int importable = 0, skipped = 0;

        for (TallyVoucher v : vouchers) {
            VoucherPlan plan = planVoucher(orgId, v);
            plans.add(plan);
            byType.merge(v.voucherType(), 1, Integer::sum);
            if ("JOURNAL".equals(plan.action())) importable++;
            else skipped++;
        }

        return new VoucherImportPreview(vouchers.size(), importable, skipped, byType, plans);
    }

    public VoucherImportResult importVouchers(byte[] xml) {
        UUID orgId = requireOrgId();
        List<TallyVoucher> vouchers = parser.parseVouchers(xml);
        Map<String, Integer> byType = new LinkedHashMap<>();
        List<RowError> errors = new ArrayList<>();
        int created = 0, skipped = 0;

        for (TallyVoucher v : vouchers) {
            byType.merge(v.voucherType(), 1, Integer::sum);
            VoucherPlan plan = planVoucher(orgId, v);
            if (!"JOURNAL".equals(plan.action())) {
                skipped++;
                continue;
            }
            try {
                postAsJournal(orgId, v);
                created++;
            } catch (Exception e) {
                String label = v.voucherType() + " " + nvl(v.voucherNumber(), "?");
                errors.add(new RowError(label, e.getMessage()));
                log.warn("Tally voucher import failed ({}): {}", label, e.getMessage());
            }
        }

        log.info("Tally voucher import: {} journals created, {} skipped, {} errors",
                created, skipped, errors.size());
        return new VoucherImportResult(created, skipped, byType, errors);
    }

    // ── Planning ─────────────────────────────────────────────────────────

    private VoucherPlan planVoucher(UUID orgId, TallyVoucher v) {
        List<String> warnings = new ArrayList<>();
        boolean allResolved = true;

        for (LedgerEntry entry : v.ledgerEntries()) {
            String code = resolveLedger(orgId, entry.ledgerName());
            if (code == null) {
                allResolved = false;
                warnings.add("Unresolved ledger: " + entry.ledgerName());
            }
        }

        BigDecimal totalDebit = BigDecimal.ZERO;
        BigDecimal totalCredit = BigDecimal.ZERO;
        for (LedgerEntry entry : v.ledgerEntries()) {
            if (entry.amount().signum() > 0) totalDebit = totalDebit.add(entry.amount());
            else totalCredit = totalCredit.add(entry.amount().abs());
        }

        BigDecimal diff = totalDebit.subtract(totalCredit).abs();
        if (diff.compareTo(new BigDecimal("0.99")) > 0) {
            warnings.add("Out of balance by " + diff.toPlainString());
        }

        String action = allResolved ? "JOURNAL" : "SKIP_UNRESOLVED";
        String detail = v.voucherType() + " #" + nvl(v.voucherNumber(), "?")
                + " | " + totalDebit.toPlainString() + " Dr";

        return new VoucherPlan(
                v.voucherType(),
                v.voucherNumber(),
                v.date() != null ? v.date().toString() : null,
                v.partyLedgerName(),
                v.narration(),
                v.ledgerEntries().size(),
                action,
                detail,
                warnings);
    }

    // ── Journal posting ─────────────────────────────────────────────────

    private void postAsJournal(UUID orgId, TallyVoucher v) {
        List<JournalLineRequest> lines = new ArrayList<>();

        for (LedgerEntry entry : v.ledgerEntries()) {
            String code = resolveLedger(orgId, entry.ledgerName());
            if (code == null) {
                throw new BusinessException("Cannot resolve ledger: " + entry.ledgerName(),
                        "TALLY_LEDGER_UNRESOLVED");
            }

            BigDecimal debit = BigDecimal.ZERO;
            BigDecimal credit = BigDecimal.ZERO;
            if (entry.amount().signum() > 0) {
                debit = entry.amount();
            } else if (entry.amount().signum() < 0) {
                credit = entry.amount().abs();
            } else {
                continue;
            }

            lines.add(new JournalLineRequest(
                    code, debit, credit,
                    entry.ledgerName(),
                    null, null));
        }

        if (lines.isEmpty()) return;

        // Balance tiny rounding differences (≤ ₹1) by adjusting the last line
        BigDecimal totalDr = lines.stream().map(JournalLineRequest::debit).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal totalCr = lines.stream().map(JournalLineRequest::credit).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal gap = totalDr.subtract(totalCr);
        if (gap.signum() != 0 && gap.abs().compareTo(BigDecimal.ONE) <= 0) {
            JournalLineRequest last = lines.get(lines.size() - 1);
            if (gap.signum() > 0) {
                lines.set(lines.size() - 1, new JournalLineRequest(
                        last.accountCode(), last.debit(), last.credit().add(gap),
                        last.description(), null, null));
            } else {
                lines.set(lines.size() - 1, new JournalLineRequest(
                        last.accountCode(), last.debit().add(gap.abs()), last.credit(),
                        last.description(), null, null));
            }
        }

        String description = "Tally " + v.voucherType()
                + (v.voucherNumber() != null ? " #" + v.voucherNumber() : "")
                + (v.partyLedgerName() != null ? " — " + v.partyLedgerName() : "")
                + (v.narration() != null ? " — " + v.narration() : "");
        if (description.length() > 500) description = description.substring(0, 500);

        journalService.postJournal(new JournalPostRequest(
                v.date(),
                description,
                "TALLY_IMPORT",
                null,
                lines,
                true));
    }

    // ── Ledger resolution ───────────────────────────────────────────────

    String resolveLedger(UUID orgId, String ledgerName) {
        if (ledgerName == null || ledgerName.isBlank()) return null;

        // 1. Contact lookup (customer → AR, vendor → AP)
        Optional<Contact> contact = contactRepository
                .findFirstByOrgIdAndDisplayNameIgnoreCaseAndIsDeletedFalse(orgId, ledgerName.trim());
        if (contact.isPresent()) {
            return contact.get().getContactType() == ContactType.CUSTOMER ? "1100" : "2010";
        }

        // 2. Account by name (Slice 1 imports + seeded CoA)
        Optional<Account> account = accountRepository
                .findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(orgId, ledgerName.trim());
        if (account.isPresent()) {
            return account.get().getCode();
        }

        // 3. Well-known Tally names
        String lower = ledgerName.trim().toLowerCase(Locale.ROOT);
        String known = WELL_KNOWN.get(lower);
        if (known != null) return known;

        // 3b. Pattern match for bank accounts ("HDFC Bank", "SBI A/c", etc.)
        if (lower.contains("bank") && !lower.contains("charge")) {
            return "1020";
        }

        return null;
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private static String nvl(String s, String fallback) {
        return s == null || s.isBlank() ? fallback : s;
    }

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
