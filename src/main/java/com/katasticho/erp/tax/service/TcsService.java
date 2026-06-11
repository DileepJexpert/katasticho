package com.katasticho.erp.tax.service;

import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.tax.service.TdsService.FyRange;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.*;

/**
 * TCS u/s 206C(1H) — the seller-side mirror of 194Q. When enabled
 * ({@code tax.tcs_enabled} org setting; the seller must have &gt; ₹10 crore
 * turnover, which is the owner's call), every sales invoice to a buyer whose
 * FY sale consideration crosses ₹50,00,000 collects TCS on the <b>excess
 * only</b>, at {@code tax.tcs_rate} (default 0.1%).
 *
 * <p>Per CBDT circular 17/2020 the consideration includes GST, so the base is
 * subtotal + tax. The FY runs April–March; aggregates count non-draft
 * invoices only. If the buyer already deducts 194Q TDS on their side, the
 * seller shouldn't also collect — flip the org setting off for that case or
 * remove the TCS from the draft invoice.
 *
 * <p>Also prepares the TCS register and quarterly Form 27EQ data, mirroring
 * {@link TdsService}'s register/26Q.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class TcsService {

    public static final String SETTING_ENABLED = "tax.tcs_enabled";
    public static final String SETTING_RATE = "tax.tcs_rate";
    static final BigDecimal THRESHOLD = new BigDecimal("5000000");   // ₹50 lakh
    public static final String DEFAULT_RATE = "0.1";

    private final InvoiceRepository invoiceRepository;
    private final ContactRepository contactRepository;
    private final OrgSettingsService orgSettingsService;

    public record TcsComputation(BigDecimal rate, BigDecimal baseAmount,
                                 BigDecimal amount, String note) {}

    // ── Computation (called from InvoiceService) ─────────────────────────

    /**
     * TCS for an invoice being created, or null when none applies.
     * {@code consideration} is the invoice value including GST, before TCS.
     */
    public TcsComputation computeForInvoice(UUID orgId, UUID contactId,
                                            BigDecimal consideration, LocalDate invoiceDate) {
        if (consideration == null || consideration.signum() <= 0) return null;
        if (!isEnabled(orgId)) return null;

        BigDecimal rate;
        try {
            rate = new BigDecimal(orgSettingsService.get(orgId, SETTING_RATE, DEFAULT_RATE));
        } catch (NumberFormatException e) {
            rate = new BigDecimal(DEFAULT_RATE);
        }
        if (rate.signum() <= 0) return null;

        FyRange fy = TdsService.fiscalYearOf(invoiceDate);
        BigDecimal aggregateBefore = nz(invoiceRepository
                .sumPostedConsiderationByOrgAndContactAndDateRange(orgId, contactId, fy.from(), fy.to()));
        BigDecimal aggregateWithThis = aggregateBefore.add(consideration);

        if (aggregateWithThis.compareTo(THRESHOLD) <= 0) {
            return null;   // below ₹50 lakh — nothing to collect yet
        }

        // Collect only on the slice above the threshold (mirrors 194Q).
        BigDecimal excess = aggregateWithThis.subtract(THRESHOLD);
        BigDecimal base = excess.min(consideration);
        BigDecimal amount = base.multiply(rate)
                .divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);
        if (amount.signum() <= 0) return null;

        return new TcsComputation(rate, base, amount,
                "206C(1H) — on sale consideration above " + THRESHOLD.toPlainString() + " this FY");
    }

    public boolean isEnabled(UUID orgId) {
        return Boolean.parseBoolean(orgSettingsService.get(orgId, SETTING_ENABLED, "false"));
    }

    // ── Register + Form 27EQ prep ────────────────────────────────────────

    /** Invoices with TCS collected in a date range — feeds the deposit challan. */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> register(LocalDate from, LocalDate to) {
        UUID orgId = requireOrgId();
        List<Invoice> invoices = invoicesWithTcs(orgId, from, to);
        Map<UUID, Contact> buyers = loadBuyers(orgId, invoices);

        List<Map<String, Object>> rows = new ArrayList<>();
        for (Invoice inv : invoices) {
            Contact buyer = buyers.get(inv.getContactId());
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("invoiceId", inv.getId());
            row.put("invoiceNumber", inv.getInvoiceNumber());
            row.put("invoiceDate", inv.getInvoiceDate());
            row.put("buyerName", buyer != null ? buyer.getDisplayName() : "");
            row.put("buyerPan", buyer != null ? nvl(buyer.getPan()) : "");
            row.put("consideration", nz(inv.getTotalAmount()).subtract(nz(inv.getTcsAmount())));
            row.put("tcsAmount", nz(inv.getTcsAmount()));
            rows.add(row);
        }
        return rows;
    }

    /**
     * Form 27EQ quarterly data: collectee-wise TCS summary for the quarter.
     * Same FY/quarter convention as {@link TdsService#form26q}.
     */
    @Transactional(readOnly = true)
    public Map<String, Object> form27eq(int fyStartYear, int quarter) {
        if (quarter < 1 || quarter > 4) {
            throw new BusinessException("Quarter must be 1-4", "TCS_BAD_QUARTER");
        }
        UUID orgId = requireOrgId();
        LocalDate from = switch (quarter) {
            case 1 -> LocalDate.of(fyStartYear, 4, 1);
            case 2 -> LocalDate.of(fyStartYear, 7, 1);
            case 3 -> LocalDate.of(fyStartYear, 10, 1);
            default -> LocalDate.of(fyStartYear + 1, 1, 1);
        };
        LocalDate to = from.plusMonths(3).minusDays(1);

        List<Invoice> invoices = invoicesWithTcs(orgId, from, to);
        Map<UUID, Contact> buyers = loadBuyers(orgId, invoices);

        Map<UUID, Map<String, Object>> grouped = new LinkedHashMap<>();
        BigDecimal totalConsideration = BigDecimal.ZERO, totalTcs = BigDecimal.ZERO;
        int missingPan = 0;

        for (Invoice inv : invoices) {
            Contact buyer = buyers.get(inv.getContactId());
            Map<String, Object> row = grouped.computeIfAbsent(inv.getContactId(), k -> {
                Map<String, Object> m = new LinkedHashMap<>();
                m.put("collecteeName", buyer != null ? buyer.getDisplayName() : "");
                m.put("collecteePan", buyer != null ? nvl(buyer.getPan()) : "");
                m.put("section", "206C(1H)");
                m.put("amountReceived", BigDecimal.ZERO);
                m.put("tcsCollected", BigDecimal.ZERO);
                m.put("invoiceCount", 0);
                return m;
            });
            BigDecimal consideration = nz(inv.getTotalAmount()).subtract(nz(inv.getTcsAmount()));
            row.put("amountReceived", ((BigDecimal) row.get("amountReceived")).add(consideration));
            row.put("tcsCollected", ((BigDecimal) row.get("tcsCollected")).add(nz(inv.getTcsAmount())));
            row.put("invoiceCount", ((Integer) row.get("invoiceCount")) + 1);
            totalConsideration = totalConsideration.add(consideration);
            totalTcs = totalTcs.add(nz(inv.getTcsAmount()));
        }
        for (Map<String, Object> row : grouped.values()) {
            if (((String) row.get("collecteePan")).isBlank()) missingPan++;
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("fy", fyStartYear + "-" + ((fyStartYear + 1) % 100));
        result.put("quarter", "Q" + quarter);
        result.put("periodFrom", from);
        result.put("periodTo", to);
        result.put("collecteeCount", grouped.size());
        result.put("totalAmountReceived", totalConsideration);
        result.put("totalTcsCollected", totalTcs);
        result.put("missingPanCount", missingPan);
        if (missingPan > 0) {
            result.put("warning", missingPan + " collectee(s) have no PAN on file — "
                    + "TCS at 1% applies without PAN and the return will be flagged.");
        }
        result.put("collectees", new ArrayList<>(grouped.values()));
        return result;
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private List<Invoice> invoicesWithTcs(UUID orgId, LocalDate from, LocalDate to) {
        return invoiceRepository.findPostedByOrgAndDateRange(orgId, from, to).stream()
                .filter(i -> nz(i.getTcsAmount()).signum() > 0)
                .toList();
    }

    private Map<UUID, Contact> loadBuyers(UUID orgId, List<Invoice> invoices) {
        Set<UUID> ids = new HashSet<>();
        invoices.forEach(i -> ids.add(i.getContactId()));
        if (ids.isEmpty()) return Map.of();
        Map<UUID, Contact> map = new HashMap<>();
        contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(orgId, ids)
                .forEach(c -> map.put(c.getId(), c));
        return map;
    }

    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }

    private static String nvl(String s) {
        return s == null ? "" : s;
    }

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
