package com.katasticho.erp.gst.service;

import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.pos.repository.SalesReceiptRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

/**
 * GST composition scheme (section 10) — the flat-rate regime most kiranas use.
 * Composition dealers don't charge GST line-by-line or claim ITC; instead they
 * pay a flat percentage of quarterly turnover via <b>CMP-08</b> (due the 18th
 * of the month after each quarter) and file an annual GSTR-4.
 *
 * <p>Org settings: {@code gst.composition_enabled} (default off) and
 * {@code gst.composition_rate} — 1% for traders/manufacturers (the default),
 * 5% for restaurants, 6% for eligible service providers. The rate splits
 * half CGST / half SGST (composition supplies are intra-state by definition).
 *
 * <p>Turnover for the statement = posted sales invoices + POS receipts for
 * the quarter. When composition is enabled, the compliance calendar swaps the
 * monthly GSTR-1/3B/2B items for CMP-08 + annual GSTR-4.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class CompositionService {

    public static final String SETTING_ENABLED = "gst.composition_enabled";
    public static final String SETTING_RATE = "gst.composition_rate";
    public static final String DEFAULT_RATE = "1";

    private final InvoiceRepository invoiceRepository;
    private final SalesReceiptRepository salesReceiptRepository;
    private final OrgSettingsService orgSettingsService;

    public boolean isEnabled(UUID orgId) {
        return Boolean.parseBoolean(orgSettingsService.get(orgId, SETTING_ENABLED, "false"));
    }

    public BigDecimal rate(UUID orgId) {
        try {
            return new BigDecimal(orgSettingsService.get(orgId, SETTING_RATE, DEFAULT_RATE));
        } catch (NumberFormatException e) {
            return new BigDecimal(DEFAULT_RATE);
        }
    }

    /**
     * CMP-08 statement for one quarter. {@code fyStartYear} is the year the FY
     * begins in; quarters are Q1 Apr–Jun … Q4 Jan–Mar (same convention as
     * 26Q/27EQ).
     */
    @Transactional(readOnly = true)
    public Map<String, Object> cmp08(int fyStartYear, int quarter) {
        if (quarter < 1 || quarter > 4) {
            throw new BusinessException("Quarter must be 1-4", "CMP08_BAD_QUARTER");
        }
        UUID orgId = requireOrgId();

        LocalDate from = switch (quarter) {
            case 1 -> LocalDate.of(fyStartYear, 4, 1);
            case 2 -> LocalDate.of(fyStartYear, 7, 1);
            case 3 -> LocalDate.of(fyStartYear, 10, 1);
            default -> LocalDate.of(fyStartYear + 1, 1, 1);
        };
        LocalDate to = from.plusMonths(3).minusDays(1);

        BigDecimal invoiceTurnover = nz(invoiceRepository
                .sumPostedTotalByOrgAndDateRange(orgId, from, to));
        BigDecimal posTurnover = nz(salesReceiptRepository
                .sumActiveTotalByOrgAndDateRange(orgId, from, to)); // exclude RETURNED from CMP-08 turnover
        BigDecimal turnover = invoiceTurnover.add(posTurnover);

        BigDecimal pct = rate(orgId);
        BigDecimal tax = turnover.multiply(pct)
                .divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);
        // Composition is intra-state by definition → equal CGST/SGST halves.
        BigDecimal cgst = tax.divide(new BigDecimal("2"), 2, RoundingMode.HALF_UP);
        BigDecimal sgst = tax.subtract(cgst);

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("fy", fyStartYear + "-" + ((fyStartYear + 1) % 100));
        out.put("quarter", "Q" + quarter);
        out.put("periodFrom", from);
        out.put("periodTo", to);
        out.put("dueDate", to.plusMonths(1).withDayOfMonth(18));
        out.put("enabled", isEnabled(orgId));
        out.put("ratePercent", pct);
        out.put("invoiceTurnover", invoiceTurnover);
        out.put("posTurnover", posTurnover);
        out.put("totalTurnover", turnover);
        out.put("taxPayable", tax);
        out.put("cgst", cgst);
        out.put("sgst", sgst);
        out.put("note", "Composition dealers issue a Bill of Supply (no GST on the bill), "
                + "cannot claim ITC, and file annual GSTR-4 by 30 April after the FY.");
        return out;
    }

    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
