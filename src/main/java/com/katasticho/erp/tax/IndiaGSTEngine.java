package com.katasticho.erp.tax;

import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.List;

/**
 * India GST TaxEngine implementation.
 * Determines CGST+SGST (intra-state) or IGST (inter-state) based on seller/buyer state.
 */
@Component
public class IndiaGSTEngine implements TaxEngine {

    @Override
    public TaxResult calculateTax(TaxableItem item, TaxContext context) {
        List<TaxComponentResult> components = new ArrayList<>();
        List<String> warnings = new ArrayList<>();

        BigDecimal gstRate = item.gstRate();
        if (gstRate == null || gstRate.compareTo(BigDecimal.ZERO) == 0) {
            return new TaxResult(components, BigDecimal.ZERO, "INDIA_GST", warnings);
        }

        BigDecimal taxableAmount = item.amount();
        boolean isInterState = !isSameState(context.sellerRegion(), context.buyerRegion());

        if (isInterState) {
            // IGST = full GST rate
            BigDecimal igstAmount = taxableAmount.multiply(gstRate)
                    .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
            components.add(new TaxComponentResult("IGST", gstRate, igstAmount, "2022"));
        } else {
            // CGST + SGST = half each
            BigDecimal halfRate = gstRate.divide(BigDecimal.valueOf(2), 2, RoundingMode.HALF_UP);
            BigDecimal cgstAmount = taxableAmount.multiply(halfRate)
                    .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
            BigDecimal sgstAmount = taxableAmount.multiply(halfRate)
                    .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);

            components.add(new TaxComponentResult("CGST", halfRate, cgstAmount, "2020"));
            components.add(new TaxComponentResult("SGST", halfRate, sgstAmount, "2021"));
        }

        BigDecimal totalTax = components.stream()
                .map(TaxComponentResult::amount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        return new TaxResult(components, totalTax, "INDIA_GST", warnings);
    }

    @Override
    public String getTaxRegimeCode() {
        return "INDIA_GST";
    }

    @Override
    public String getTaxLabel() {
        return "GST";
    }

    @Override
    public String getTaxIdLabel() {
        return "GSTIN";
    }

    @Override
    public List<String> getComponentLabels() {
        return List.of("CGST", "SGST", "IGST");
    }

    private boolean isSameState(String sellerState, String buyerState) {
        if (sellerState == null || buyerState == null) return true;
        return sellerState.equalsIgnoreCase(buyerState);
    }
}
