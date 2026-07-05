package com.katasticho.erp.fieldsales.service;

import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.expense.dto.CreateExpenseRequest;
import com.katasticho.erp.expense.dto.ExpenseResponse;
import com.katasticho.erp.expense.service.ExpenseService;
import com.katasticho.erp.fieldsales.entity.FieldAllowanceClaim;
import com.katasticho.erp.fieldsales.entity.FieldLocationPing;
import com.katasticho.erp.fieldsales.repository.FieldAllowanceClaimRepository;
import com.katasticho.erp.fieldsales.repository.FieldLocationPingRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * TA/DA field allowance for any vertical: travel allowance is computed
 * from the day's GPS distance trail (org setting `field_sales.ta_per_km`),
 * plus a flat daily allowance (`field_sales.da_per_day`). Claiming creates
 * a normal expense (Travel & Conveyance 5240, paid through Cash 1010) so
 * all accounting flows through the existing expense module. One claim per
 * salesperson per day.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class FieldAllowanceService {

    static final String SETTING_TA_PER_KM = "field_sales.ta_per_km";
    static final String SETTING_DA_PER_DAY = "field_sales.da_per_day";
    /** GPS (strict, claim = tracked km) | FLEXIBLE (tracked km, adjustable) | MANUAL (salesperson enters km). */
    static final String SETTING_MODE = "field_sales.allowance_mode";
    private static final String TRAVEL_EXPENSE_CODE = "5240";
    private static final String CASH_CODE = "1010";

    private final FieldLocationPingRepository pingRepository;
    private final FieldAllowanceClaimRepository claimRepository;
    private final OrgSettingsService orgSettingsService;
    private final ExpenseService expenseService;
    private final AccountRepository accountRepository;

    /** Computed (not yet necessarily claimed) allowance for the current user. */
    @Transactional(readOnly = true)
    public Map<String, Object> computeAllowance(LocalDate date) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        BigDecimal distanceKm = travelledKm(orgId, userId, date);
        BigDecimal taPerKm = setting(orgId, SETTING_TA_PER_KM);
        BigDecimal daPerDay = setting(orgId, SETTING_DA_PER_DAY);
        BigDecimal taAmount = distanceKm.multiply(taPerKm).setScale(2, RoundingMode.HALF_UP);
        // DA applies only on days with actual field movement (any GPS trail)
        BigDecimal daAmount = distanceKm.signum() > 0 ? daPerDay : BigDecimal.ZERO;
        String mode = mode(orgId);

        FieldAllowanceClaim existing = claimRepository
                .findByOrgIdAndSalespersonIdAndClaimDate(orgId, userId, date).orElse(null);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("date", date);
        result.put("distanceKm", distanceKm);
        result.put("taPerKm", taPerKm);
        result.put("taAmount", taAmount);
        result.put("daAmount", daAmount);
        result.put("totalAmount", taAmount.add(daAmount));
        result.put("mode", mode);
        result.put("kmEditable", !"GPS".equals(mode));
        result.put("configured", taPerKm.signum() > 0 || daPerDay.signum() > 0);
        result.put("claimed", existing != null);
        result.put("claimedKm", existing != null ? existing.getDistanceKm() : null);
        result.put("expenseId", existing != null ? existing.getExpenseId() : null);
        return result;
    }

    /**
     * Claims the day's allowance: creates the expense and records the claim.
     *
     * The claimed distance depends on the org's allowance mode:
     * GPS uses the tracked km as-is; FLEXIBLE lets the salesperson adjust
     * it (e.g. deduct a personal detour) with the GPS km kept as reference;
     * MANUAL requires the salesperson to enter km themselves. The expense
     * description always carries both figures so approvers see variances.
     */
    @Transactional
    public FieldAllowanceClaim claim(LocalDate date, BigDecimal requestedKm) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        claimRepository.findByOrgIdAndSalespersonIdAndClaimDate(orgId, userId, date)
                .ifPresent(c -> {
                    throw new BusinessException("Allowance for " + date + " is already claimed",
                            "FS_ALLOWANCE_ALREADY_CLAIMED", HttpStatus.CONFLICT);
                });

        BigDecimal gpsKm = travelledKm(orgId, userId, date);
        BigDecimal distanceKm = resolveClaimedKm(mode(orgId), gpsKm, requestedKm);
        BigDecimal taPerKm = setting(orgId, SETTING_TA_PER_KM);
        BigDecimal daPerDay = setting(orgId, SETTING_DA_PER_DAY);
        BigDecimal taAmount = distanceKm.multiply(taPerKm).setScale(2, RoundingMode.HALF_UP);
        BigDecimal daAmount = distanceKm.signum() > 0 ? daPerDay : BigDecimal.ZERO;
        BigDecimal total = taAmount.add(daAmount);

        if (total.signum() <= 0) {
            throw new BusinessException(
                    "Nothing to claim — no travel recorded for " + date
                            + " or allowance rates are not configured"
                            + " (org settings " + SETTING_TA_PER_KM + " / " + SETTING_DA_PER_DAY + ")",
                    "FS_ALLOWANCE_NOTHING_TO_CLAIM", HttpStatus.BAD_REQUEST);
        }

        Account travel = accountRepository
                .findByOrgIdAndCodeAndIsDeletedFalse(orgId, TRAVEL_EXPENSE_CODE)
                .orElseThrow(() -> new BusinessException(
                        "Travel & Conveyance account (" + TRAVEL_EXPENSE_CODE + ") not found",
                        "FS_ALLOWANCE_ACCOUNT_MISSING", HttpStatus.BAD_REQUEST));
        Account cash = accountRepository
                .findByOrgIdAndCodeAndIsDeletedFalse(orgId, CASH_CODE)
                .orElseThrow(() -> new BusinessException(
                        "Cash account (" + CASH_CODE + ") not found",
                        "FS_ALLOWANCE_ACCOUNT_MISSING", HttpStatus.BAD_REQUEST));

        String kmNote = distanceKm.compareTo(gpsKm) == 0
                ? distanceKm + " km"
                : distanceKm + " km claimed (GPS " + gpsKm + " km)";
        ExpenseResponse expense = expenseService.createExpense(new CreateExpenseRequest(
                date, travel.getId(), "Field Allowance",
                "TA/DA " + date + " — " + kmNote
                        + " (TA " + taAmount + " + DA " + daAmount + ")",
                total, BigDecimal.ZERO, "INR", null,
                "CASH", cash.getId(),
                false, null, null, null, null));

        FieldAllowanceClaim claim = claimRepository.save(FieldAllowanceClaim.builder()
                .orgId(orgId).salespersonId(userId).claimDate(date)
                .distanceKm(distanceKm).gpsDistanceKm(gpsKm)
                .taAmount(taAmount).daAmount(daAmount).totalAmount(total)
                .expenseId(expense.id())
                .build());
        log.info("Allowance claimed for {} by {}: {} km (GPS {}), total {} (expense {})",
                date, userId, distanceKm, gpsKm, total, expense.id());
        return claim;
    }

    /** Effective claimed km for the org's mode; never negative, 2dp. */
    private BigDecimal resolveClaimedKm(String mode, BigDecimal gpsKm, BigDecimal requestedKm) {
        BigDecimal km = switch (mode) {
            case "GPS" -> gpsKm;
            case "MANUAL" -> {
                if (requestedKm == null) {
                    throw new BusinessException(
                            "Distance in km is required — this organisation uses manual allowance entry",
                            "FS_ALLOWANCE_KM_REQUIRED", HttpStatus.BAD_REQUEST);
                }
                yield requestedKm;
            }
            // FLEXIBLE: salesperson may adjust DOWN (e.g. deduct personal travel),
            // but never above the GPS-recorded trail — cap at gpsKm so a claim can't
            // inflate the reimbursable distance beyond what was actually driven.
            default -> requestedKm != null ? requestedKm.min(gpsKm) : gpsKm;
        };
        if (km.signum() < 0) {
            throw new BusinessException("Distance cannot be negative",
                    "FS_ALLOWANCE_KM_INVALID", HttpStatus.BAD_REQUEST);
        }
        return km.setScale(2, RoundingMode.HALF_UP);
    }

    private String mode(UUID orgId) {
        return orgSettingsService.get(orgId, SETTING_MODE, "FLEXIBLE").toUpperCase();
    }

    @Transactional(readOnly = true)
    public List<FieldAllowanceClaim> myClaims() {
        return claimRepository.findByOrgIdAndSalespersonIdOrderByClaimDateDesc(
                TenantContext.getCurrentOrgId(), TenantContext.getCurrentUserId());
    }

    /** Haversine sum over the day's GPS pings (UTC day window), in km. */
    private BigDecimal travelledKm(UUID orgId, UUID salespersonId, LocalDate date) {
        Instant from = date.atStartOfDay().toInstant(ZoneOffset.UTC);
        Instant to = date.plusDays(1).atStartOfDay().toInstant(ZoneOffset.UTC);
        List<FieldLocationPing> pings = pingRepository
                .findByOrgIdAndSalespersonIdAndRecordedAtBetweenOrderByRecordedAtAsc(
                        orgId, salespersonId, from, to);
        double meters = 0;
        for (int i = 1; i < pings.size(); i++) {
            meters += FieldTrackingService.distanceMeters(
                    pings.get(i - 1).getLatitude(), pings.get(i - 1).getLongitude(),
                    pings.get(i).getLatitude(), pings.get(i).getLongitude());
        }
        return BigDecimal.valueOf(meters / 1000.0).setScale(2, RoundingMode.HALF_UP);
    }

    private BigDecimal setting(UUID orgId, String key) {
        try {
            return new BigDecimal(orgSettingsService.get(orgId, key, "0"));
        } catch (NumberFormatException e) {
            return BigDecimal.ZERO;
        }
    }
}
