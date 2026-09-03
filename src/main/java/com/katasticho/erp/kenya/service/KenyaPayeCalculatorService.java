package com.katasticho.erp.kenya.service;

import com.katasticho.erp.kenya.dto.KenyaPayeCalculationRequest;
import com.katasticho.erp.kenya.dto.KenyaPayeCalculationResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;

@Service
@Slf4j
public class KenyaPayeCalculatorService {

    // Monthly Personal Relief (KSh 2,400 per month)
    private static final BigDecimal PERSONAL_RELIEF = new BigDecimal("2400.00");
    // NSSF Tier 1 limit (KSh 8,000 * 6% = 480)
    private static final BigDecimal NSSF_TIER1_MAX = new BigDecimal("480.00");
    // NSSF Tier 2 max (KSh 28,000 * 6% = 1680)
    private static final BigDecimal NSSF_TIER2_MAX = new BigDecimal("1680.00");
    // SHIF Rate = 2.75% of Gross
    private static final BigDecimal SHIF_RATE = new BigDecimal("0.0275");
    // Affordable Housing Levy Rate = 1.5% of Gross
    private static final BigDecimal HOUSING_LEVY_RATE = new BigDecimal("0.015");

    public KenyaPayeCalculationResponse calculate(KenyaPayeCalculationRequest req) {
        BigDecimal gross = req.getGrossSalary() != null ? req.getGrossSalary() : BigDecimal.ZERO;

        // 1. Calculate NSSF Tier I & Tier II
        BigDecimal nssfTier1 = gross.min(new BigDecimal("8000.00"))
                .multiply(new BigDecimal("0.06"))
                .min(NSSF_TIER1_MAX)
                .setScale(2, RoundingMode.HALF_UP);

        BigDecimal nssfTier2 = BigDecimal.ZERO;
        if (gross.compareTo(new BigDecimal("8000.00")) > 0) {
            BigDecimal tier2Base = gross.min(new BigDecimal("36000.00")).subtract(new BigDecimal("8000.00"));
            nssfTier2 = tier2Base.multiply(new BigDecimal("0.06")).min(NSSF_TIER2_MAX).setScale(2, RoundingMode.HALF_UP);
        }
        BigDecimal totalNssf = nssfTier1.add(nssfTier2);

        // 2. Taxable Pay = Gross - NSSF - Pension Contribution
        BigDecimal pension = req.getPensionContribution() != null ? req.getPensionContribution() : BigDecimal.ZERO;
        BigDecimal taxablePay = gross.subtract(totalNssf).subtract(pension).max(BigDecimal.ZERO);

        // 3. Graduated PAYE Tax Brackets (2024/2026 Kenyan Tax Law)
        BigDecimal grossPaye = calculateGrossPaye(taxablePay);

        // 4. Reliefs
        BigDecimal personalRelief = PERSONAL_RELIEF;
        BigDecimal netPaye = grossPaye.subtract(personalRelief).max(BigDecimal.ZERO).setScale(2, RoundingMode.HALF_UP);

        // 5. SHIF (Social Health Insurance Fund) - 2.75% of Gross
        BigDecimal shifAmount = gross.multiply(SHIF_RATE).setScale(2, RoundingMode.HALF_UP);

        // 6. Affordable Housing Levy - 1.5% of Gross
        BigDecimal housingLevy = gross.multiply(HOUSING_LEVY_RATE).setScale(2, RoundingMode.HALF_UP);

        // 7. Total Deductions & Net Pay
        BigDecimal totalDeductions = totalNssf.add(netPaye).add(shifAmount).add(housingLevy);
        BigDecimal netPay = gross.subtract(totalDeductions).setScale(2, RoundingMode.HALF_UP);

        return KenyaPayeCalculationResponse.builder()
                .grossSalary(gross)
                .nssfTier1(nssfTier1)
                .nssfTier2(nssfTier2)
                .totalNssf(totalNssf)
                .taxablePay(taxablePay)
                .grossPaye(grossPaye)
                .personalRelief(personalRelief)
                .insuranceRelief(BigDecimal.ZERO)
                .netPaye(netPaye)
                .shifAmount(shifAmount)
                .housingLevyAmount(housingLevy)
                .totalDeductions(totalDeductions)
                .netPay(netPay)
                .build();
    }

    private BigDecimal calculateGrossPaye(BigDecimal taxable) {
        BigDecimal tax = BigDecimal.ZERO;
        BigDecimal remaining = taxable;

        // Band 1: Up to KSh 24,000 @ 10%
        if (remaining.compareTo(BigDecimal.ZERO) > 0) {
            BigDecimal band1 = remaining.min(new BigDecimal("24000.00"));
            tax = tax.add(band1.multiply(new BigDecimal("0.10")));
            remaining = remaining.subtract(band1);
        }

        // Band 2: Next KSh 8,333.33 (24,001 - 32,333.33) @ 25%
        if (remaining.compareTo(BigDecimal.ZERO) > 0) {
            BigDecimal band2 = remaining.min(new BigDecimal("8333.33"));
            tax = tax.add(band2.multiply(new BigDecimal("0.25")));
            remaining = remaining.subtract(band2);
        }

        // Band 3: Next KSh 467,666.67 (32,334 - 500,000) @ 30%
        if (remaining.compareTo(BigDecimal.ZERO) > 0) {
            BigDecimal band3 = remaining.min(new BigDecimal("467666.67"));
            tax = tax.add(band3.multiply(new BigDecimal("0.30")));
            remaining = remaining.subtract(band3);
        }

        // Band 4: Next KSh 300,000 (500,001 - 800,000) @ 32.5%
        if (remaining.compareTo(BigDecimal.ZERO) > 0) {
            BigDecimal band4 = remaining.min(new BigDecimal("300000.00"));
            tax = tax.add(band4.multiply(new BigDecimal("0.325")));
            remaining = remaining.subtract(band4);
        }

        // Band 5: Above KSh 800,000 @ 35%
        if (remaining.compareTo(BigDecimal.ZERO) > 0) {
            tax = tax.add(remaining.multiply(new BigDecimal("0.35")));
        }

        return tax.setScale(2, RoundingMode.HALF_UP);
    }
}