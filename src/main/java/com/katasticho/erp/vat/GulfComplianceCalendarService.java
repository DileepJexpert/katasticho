package com.katasticho.erp.vat;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.country.CountryAccessService;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.hr.entity.Offboarding;
import com.katasticho.erp.hr.repository.OffboardingRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Gulf (AE/OM) analogue of {@link com.katasticho.erp.gst.service.GstComplianceCalendarService}.
 *
 * <p>Surfaces the deadlines a Gulf SMB owner actually misses without a nudge:
 * the quarterly VAT return (UAE FTA VAT201 — due 28th of month following the
 * quarter; Oman OTA VAT return — due 30th, per Article 72 of OM VAT Law) and
 * any pending end-of-service gratuity payouts whose last working day has
 * already passed but whose journal hasn't been posted yet.
 *
 * <p>Country-gated by the controller — this service trusts its caller for the
 * AE/OM contract and returns a country-aware list of items either way.
 */
@Service
@RequiredArgsConstructor
public class GulfComplianceCalendarService {

    private static final int DUE_SOON_DAYS = 5;

    private final CountryAccessService countryAccessService;
    private final OffboardingRepository offboardingRepository;
    private final Clock clock;

    @Transactional(readOnly = true)
    public List<Map<String, Object>> calendar() {
        UUID orgId = requireOrgId();
        String country = countryAccessService.countryOf(orgId);
        LocalDate today = LocalDate.now(clock);

        List<Map<String, Object>> items = new ArrayList<>();
        items.add(vatReturnItem(country, today));
        items.addAll(pendingGratuityItems(orgId, today));
        return items;
    }

    /**
     * Quarterly VAT return for the most recently ended calendar quarter.
     *
     * <p>UAE FTA: the standard tax period is quarterly and the return + payment
     * are due 28 days after the period closes. Oman OTA: 30 days. Large
     * taxpayers in either country may file monthly under a special direction
     * from the regulator — that's an edge case we'll model when a customer
     * needs it.
     */
    private Map<String, Object> vatReturnItem(String country, LocalDate today) {
        int month = today.getMonthValue();
        LocalDate quarterEnd = switch ((month - 1) / 3) {
            case 0 -> LocalDate.of(today.getYear() - 1, 12, 31);   // Jan–Mar → Oct–Dec ended
            case 1 -> LocalDate.of(today.getYear(), 3, 31);        // Apr–Jun → Jan–Mar ended
            case 2 -> LocalDate.of(today.getYear(), 6, 30);        // Jul–Sep → Apr–Jun ended
            default -> LocalDate.of(today.getYear(), 9, 30);       // Oct–Dec → Jul–Sep ended
        };
        int dueDay = "AE".equals(country) ? 28 : 30;
        LocalDate dueDate = quarterEnd.plusMonths(1).withDayOfMonth(dueDay);
        String code = "AE".equals(country) ? "VAT201" : "OMAN_VAT_RETURN";
        String title = "AE".equals(country)
                ? "File VAT201 (UAE FTA quarterly return)"
                : "File quarterly VAT return (Oman OTA)";
        String desc = "AE".equals(country)
                ? "Box rollups are pre-built — export the JSON from VAT → UAE Return and file in EmaraTax."
                : "Box rollups are pre-built — export the JSON from VAT → Oman Return and file in the OTA portal.";
        Map<String, Object> item = item(code, title,
                YearMonth.from(quarterEnd), dueDate, today, desc);
        item.put("period", "Quarter ending " + quarterEnd);
        return item;
    }

    /**
     * Gratuity payouts that should have already been posted: AE/OM
     * offboardings still INITIATED, with a last working day on or before today,
     * and no gratuity journal yet. Each surfaces as an OVERDUE row so the
     * accountant clears them out via the {@code /pay-gratuity} endpoint.
     */
    private List<Map<String, Object>> pendingGratuityItems(UUID orgId, LocalDate today) {
        String country = countryAccessService.countryOf(orgId);
        if (!"AE".equals(country) && !"OM".equals(country)) {
            return List.of();
        }
        List<Offboarding> open = offboardingRepository
                .findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(orgId, "INITIATED");
        List<Map<String, Object>> rows = new ArrayList<>();
        for (Offboarding ob : open) {
            if (ob.getGratuityJournalEntryId() != null) continue;
            LocalDate lwd = ob.getLastWorkingDay();
            if (lwd == null || lwd.isAfter(today)) continue;
            long daysLeft = ChronoUnit.DAYS.between(today, lwd);
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("code", "GRATUITY_PENDING");
            m.put("title", "Pay end-of-service gratuity for offboarding " + ob.getId());
            m.put("period", YearMonth.from(lwd).toString());
            m.put("dueDate", lwd);
            m.put("daysLeft", daysLeft);
            m.put("status", "OVERDUE");
            m.put("description",
                    "Last working day was " + lwd + " — post the payout via HR → Offboarding → Pay gratuity.");
            m.put("offboardingId", ob.getId());
            rows.add(m);
        }
        return rows;
    }

    private Map<String, Object> item(String code, String title, YearMonth period,
                                     LocalDate dueDate, LocalDate today, String description) {
        long daysLeft = ChronoUnit.DAYS.between(today, dueDate);
        String status = daysLeft < 0 ? "OVERDUE" : (daysLeft <= DUE_SOON_DAYS ? "DUE_SOON" : "UPCOMING");
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("code", code);
        m.put("title", title);
        m.put("period", period.toString());
        m.put("dueDate", dueDate);
        m.put("daysLeft", daysLeft);
        m.put("status", status);
        m.put("description", description);
        return m;
    }

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
