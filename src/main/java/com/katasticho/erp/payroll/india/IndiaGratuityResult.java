package com.katasticho.erp.payroll.india;

import java.math.BigDecimal;

/**
 * India gratuity computation under the Payment of Gratuity Act 1972.
 *
 * <p>Shows the formula AND the inputs together so an HR officer can audit the
 * number. Distinct from the Gulf {@code GratuityResult} — India uses a 15/26
 * day fraction and completed-year rounding (Act 4(2)) rather than the Gulf's
 * day-tier scheme.
 *
 * @param yearsExact        service in years as a decimal (e.g. {@code 5.583})
 * @param completedYears    years used in the formula after Act 4(2) rounding
 *                          (final year &ge; 6 months rounds up)
 * @param eligible          {@code true} once 5 continuous years are completed
 * @param monthlyBasicPlusDa last-drawn basic + dearness allowance per month
 * @param gratuityAmount    {@code basic+DA × 15/26 × completedYears} (uncapped)
 * @param cappedAmount      {@code min(gratuityAmount, ₹20,00,000)} — the
 *                          statutory ceiling, applied at payout
 * @param formula           human-readable description for the payslip/preview
 */
public record IndiaGratuityResult(
        BigDecimal yearsExact,
        int completedYears,
        boolean eligible,
        BigDecimal monthlyBasicPlusDa,
        BigDecimal gratuityAmount,
        BigDecimal cappedAmount,
        String formula
) {
}
