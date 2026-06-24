package com.katasticho.erp.payroll.gulf;

import java.math.BigDecimal;

/**
 * End-of-service gratuity calculation for the current org's country.
 *
 * <p>Returned from {@link GulfPayrollService#computeGratuity}. The intent is
 * to show the formula AND the inputs together so an HR officer can audit the
 * number — not just hand back a single rupee figure.
 *
 * @param country        ISO alpha-2 country code (AE / OM)
 * @param yearsExact     years of service as a decimal (e.g. {@code 5.500})
 * @param dailyBasic     monthly basic ÷ 30
 * @param entitledDays   computed days of basic per the country's formula
 * @param grossGratuity  {@code dailyBasic × entitledDays}
 * @param cappedGratuity {@code min(grossGratuity, 24 × monthlyBasic)} —
 *                       UAE / Oman both cap at two years' total wage
 * @param formula        human-readable description of how the number was computed,
 *                       suitable for showing on the payslip footer
 */
public record GratuityResult(
        String country,
        BigDecimal yearsExact,
        BigDecimal dailyBasic,
        BigDecimal entitledDays,
        BigDecimal grossGratuity,
        BigDecimal cappedGratuity,
        String formula
) {
}
