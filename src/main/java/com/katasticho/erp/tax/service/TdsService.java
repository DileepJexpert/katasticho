package com.katasticho.erp.tax.service;

import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.*;

/**
 * TDS (income-tax withholding) on vendor bills, by section.
 *
 * <p>The vendor master carries the decision ({@code tdsApplicable},
 * {@code tdsSection}, {@code tdsRate}); this service applies the section's
 * statutory thresholds before deducting:
 * <ul>
 *   <li><b>194C</b> — single bill &gt; ₹30,000 OR FY aggregate &gt; ₹1,00,000</li>
 *   <li><b>194J</b> — FY aggregate &gt; ₹30,000</li>
 *   <li><b>194H</b> — FY aggregate &gt; ₹20,000</li>
 *   <li><b>194I</b> — FY aggregate &gt; ₹2,40,000</li>
 *   <li><b>194A</b> — FY aggregate &gt; ₹5,000</li>
 *   <li><b>194Q</b> — FY aggregate &gt; ₹50,00,000; TDS only on the excess</li>
 * </ul>
 * TDS is computed on the taxable value (excluding GST, per CBDT circular
 * 23/2017). The FY runs April–March; aggregates count posted bills only.
 *
 * <p>Also prepares the quarterly Form 26Q data (deductee-wise summary) and a
 * TDS register for the deposit challan.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class TdsService {

    /** section → [single-bill threshold (nullable), FY-aggregate threshold (nullable)] */
    private static final Map<String, BigDecimal[]> SECTION_THRESHOLDS = Map.of(
            "194C", new BigDecimal[]{new BigDecimal("30000"), new BigDecimal("100000")},
            "194J", new BigDecimal[]{null, new BigDecimal("30000")},
            "194H", new BigDecimal[]{null, new BigDecimal("20000")},
            "194I", new BigDecimal[]{null, new BigDecimal("240000")},
            "194A", new BigDecimal[]{null, new BigDecimal("5000")},
            "194Q", new BigDecimal[]{null, new BigDecimal("5000000")}
    );

    private final PurchaseBillRepository purchaseBillRepository;
    private final ContactRepository contactRepository;

    public record TdsComputation(String section, BigDecimal rate, BigDecimal baseAmount,
                                 BigDecimal amount, String note) {}

    // ── Computation (called from PurchaseBillService) ────────────────────

    /**
     * TDS for a bill being created/edited, or null when none applies.
     * The bill itself is DRAFT at this point, so the posted FY aggregate
     * never double-counts it.
     */
    public TdsComputation computeForBill(UUID orgId, Contact vendor,
                                         BigDecimal taxableBase, LocalDate billDate) {
        if (vendor == null || !vendor.isTdsApplicable()) return null;
        if (taxableBase == null || taxableBase.signum() <= 0) return null;

        BigDecimal rate = vendor.getTdsRate();
        if (rate == null || rate.signum() <= 0) {
            log.info("Vendor {} is TDS-applicable but has no TDS rate set — skipping deduction",
                    vendor.getDisplayName());
            return null;
        }

        String section = vendor.getTdsSection() == null ? "" : vendor.getTdsSection().trim().toUpperCase();
        BigDecimal[] thresholds = SECTION_THRESHOLDS.get(section);

        BigDecimal deductibleBase;
        String note;
        if (thresholds == null) {
            // Unknown/blank section: the vendor flag alone decides — deduct on the full base.
            deductibleBase = taxableBase;
            note = "TDS per vendor master" + (section.isEmpty() ? "" : " (section " + section + ")");
        } else {
            BigDecimal single = thresholds[0];
            BigDecimal annual = thresholds[1];
            FyRange fy = fiscalYearOf(billDate);
            BigDecimal aggregateBefore = nz(purchaseBillRepository
                    .sumPostedSubtotalByOrgAndContactAndDateRange(orgId, vendor.getId(), fy.from(), fy.to()));
            BigDecimal aggregateWithThis = aggregateBefore.add(taxableBase);

            boolean singleHit = single != null && taxableBase.compareTo(single) > 0;
            boolean annualHit = annual != null && aggregateWithThis.compareTo(annual) > 0;

            if (!singleHit && !annualHit) {
                return null; // below thresholds — no deduction yet
            }
            if ("194Q".equals(section) && !singleHit) {
                // 194Q: deduct only on the purchase value above ₹50 lakh.
                BigDecimal excess = aggregateWithThis.subtract(annual);
                deductibleBase = excess.min(taxableBase);
                note = "194Q — on purchases above " + annual.toPlainString() + " this FY";
            } else if (annualHit && aggregateBefore.compareTo(annual) <= 0) {
                // First bill to push the FY aggregate over the threshold. For an
                // aggregate-threshold section, once crossed TDS applies to the WHOLE
                // amount paid/credited in the year — the earlier sub-threshold bills
                // that escaped deduction must be caught up now, NOT just this bill.
                // Net out any base already taxed under 194C's single-bill limb so a
                // prior single-limb bill isn't double-deducted (0 for pure-aggregate
                // sections 194J/H/I/A → collapses to the full aggregate).
                BigDecimal alreadyTaxedBase = nz(purchaseBillRepository
                        .sumPostedTaxedSubtotalByOrgAndContactAndDateRange(
                                orgId, vendor.getId(), fy.from(), fy.to()));
                deductibleBase = aggregateWithThis.subtract(alreadyTaxedBase).max(BigDecimal.ZERO);
                note = section + " — FY aggregate above " + annual.toPlainString()
                        + " (caught up on the whole year)";
            } else {
                // Single-bill crossing with the aggregate still under, OR a
                // subsequent bill after the aggregate already crossed (prior
                // aggregate already bore TDS) — deduct on this bill's base only.
                deductibleBase = taxableBase;
                note = section + (singleHit
                        ? " — single bill above " + single.toPlainString()
                        : " — FY aggregate above " + annual.toPlainString());
            }
        }

        BigDecimal amount = deductibleBase.multiply(rate)
                .divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);
        if (amount.signum() <= 0) return null;
        String effectiveSection = section.isEmpty() ? "TDS" : section;
        return new TdsComputation(effectiveSection, rate, deductibleBase, amount, note);
    }

    // ── Register + Form 26Q prep ─────────────────────────────────────────

    /** Bills with TDS deducted in a date range — feeds the deposit challan. */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> register(LocalDate from, LocalDate to) {
        UUID orgId = requireOrgId();
        List<PurchaseBill> bills = billsWithTds(orgId, from, to);
        Map<UUID, Contact> vendors = loadVendors(orgId, bills);

        List<Map<String, Object>> rows = new ArrayList<>();
        for (PurchaseBill bill : bills) {
            Contact vendor = vendors.get(bill.getContactId());
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("billId", bill.getId());
            row.put("billNumber", bill.getBillNumber());
            row.put("vendorBillNumber", bill.getVendorBillNumber());
            row.put("billDate", bill.getBillDate());
            row.put("vendorName", vendor != null ? vendor.getDisplayName() : "");
            row.put("vendorPan", vendor != null ? nvl(vendor.getPan()) : "");
            row.put("section", nvl(bill.getTdsSection()));
            row.put("taxableBase", nz(bill.getSubtotal()));
            row.put("tdsAmount", nz(bill.getTdsAmount()));
            rows.add(row);
        }
        return rows;
    }

    /**
     * Form 26Q quarterly data: deductee-wise TDS summary for the quarter.
     * {@code fyStartYear} is the year the FY begins in (2026 = FY 2026-27);
     * quarters are Q1 Apr–Jun … Q4 Jan–Mar.
     */
    @Transactional(readOnly = true)
    public Map<String, Object> form26q(int fyStartYear, int quarter) {
        if (quarter < 1 || quarter > 4) {
            throw new BusinessException("Quarter must be 1-4", "TDS_BAD_QUARTER");
        }
        UUID orgId = requireOrgId();
        LocalDate from = switch (quarter) {
            case 1 -> LocalDate.of(fyStartYear, 4, 1);
            case 2 -> LocalDate.of(fyStartYear, 7, 1);
            case 3 -> LocalDate.of(fyStartYear, 10, 1);
            default -> LocalDate.of(fyStartYear + 1, 1, 1);
        };
        LocalDate to = from.plusMonths(3).minusDays(1);

        List<PurchaseBill> bills = billsWithTds(orgId, from, to);
        Map<UUID, Contact> vendors = loadVendors(orgId, bills);

        record Key(UUID vendorId, String section) {}
        Map<Key, Map<String, Object>> grouped = new LinkedHashMap<>();
        BigDecimal totalPaid = BigDecimal.ZERO, totalTds = BigDecimal.ZERO;
        int missingPan = 0;

        for (PurchaseBill bill : bills) {
            Contact vendor = vendors.get(bill.getContactId());
            Key key = new Key(bill.getContactId(), nvl(bill.getTdsSection()));
            Map<String, Object> row = grouped.computeIfAbsent(key, k -> {
                Map<String, Object> m = new LinkedHashMap<>();
                m.put("deducteeName", vendor != null ? vendor.getDisplayName() : "");
                m.put("deducteePan", vendor != null ? nvl(vendor.getPan()) : "");
                m.put("section", k.section());
                m.put("amountPaid", BigDecimal.ZERO);
                m.put("tdsDeducted", BigDecimal.ZERO);
                m.put("billCount", 0);
                return m;
            });
            row.put("amountPaid", ((BigDecimal) row.get("amountPaid")).add(nz(bill.getSubtotal())));
            row.put("tdsDeducted", ((BigDecimal) row.get("tdsDeducted")).add(nz(bill.getTdsAmount())));
            row.put("billCount", ((Integer) row.get("billCount")) + 1);
            totalPaid = totalPaid.add(nz(bill.getSubtotal()));
            totalTds = totalTds.add(nz(bill.getTdsAmount()));
        }
        for (Map<String, Object> row : grouped.values()) {
            if (((String) row.get("deducteePan")).isBlank()) missingPan++;
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("fy", fyStartYear + "-" + ((fyStartYear + 1) % 100));
        result.put("quarter", "Q" + quarter);
        result.put("periodFrom", from);
        result.put("periodTo", to);
        result.put("deducteeCount", grouped.size());
        result.put("totalAmountPaid", totalPaid);
        result.put("totalTdsDeducted", totalTds);
        result.put("missingPanCount", missingPan);
        if (missingPan > 0) {
            result.put("warning", missingPan + " deductee(s) have no PAN on file — "
                    + "TDS at 20% applies without PAN and the return will be flagged.");
        }
        result.put("deductees", new ArrayList<>(grouped.values()));
        return result;
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    record FyRange(LocalDate from, LocalDate to) {}

    static FyRange fiscalYearOf(LocalDate date) {
        int startYear = date.getMonthValue() >= 4 ? date.getYear() : date.getYear() - 1;
        return new FyRange(LocalDate.of(startYear, 4, 1), LocalDate.of(startYear + 1, 3, 31));
    }

    private List<PurchaseBill> billsWithTds(UUID orgId, LocalDate from, LocalDate to) {
        return purchaseBillRepository.findPostedByOrgAndDateRange(orgId, from, to).stream()
                .filter(b -> nz(b.getTdsAmount()).signum() > 0)
                .toList();
    }

    private Map<UUID, Contact> loadVendors(UUID orgId, List<PurchaseBill> bills) {
        Set<UUID> ids = new HashSet<>();
        bills.forEach(b -> ids.add(b.getContactId()));
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
