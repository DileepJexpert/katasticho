package com.katasticho.erp.pos.dto;

/**
 * Pre-computed discount percentages at which the margin band changes.
 * Flutter checks: if discount > blockAt -> black, > redMax -> red, etc.
 */
public record DiscountThresholds(
    String initialBand,   // GREEN, BLUE, YELLOW, RED, BLOCK
    double blueMax,       // discount % where margin drops to blueThreshold
    double yellowMax,     // discount % where margin drops to yellowThreshold
    double redMax,        // discount % where margin drops to redThreshold
    double blockAt        // discount % where margin goes negative
) {
    // Default band thresholds (margin percentages)
    private static final double GREEN_THRESHOLD = 20.0;
    private static final double BLUE_THRESHOLD = 10.0;
    private static final double YELLOW_THRESHOLD = 3.0;
    private static final double RED_THRESHOLD = 0.0;

    public static DiscountThresholds compute(double salePrice, double purchasePrice) {
        if (salePrice <= 0 || purchasePrice <= 0) {
            return new DiscountThresholds("GREEN", 100, 100, 100, 100);
        }

        double originalMargin = (salePrice - purchasePrice) / salePrice * 100;

        double blueMax = discountToReachMargin(salePrice, purchasePrice, GREEN_THRESHOLD);
        double yellowMax = discountToReachMargin(salePrice, purchasePrice, BLUE_THRESHOLD);
        double redMax = discountToReachMargin(salePrice, purchasePrice, YELLOW_THRESHOLD);
        double blockAt = discountToReachMargin(salePrice, purchasePrice, RED_THRESHOLD);

        String initialBand;
        if (originalMargin > GREEN_THRESHOLD) {
            initialBand = "GREEN";
        } else if (originalMargin > BLUE_THRESHOLD) {
            initialBand = "BLUE";
        } else if (originalMargin > YELLOW_THRESHOLD) {
            initialBand = "YELLOW";
        } else if (originalMargin > RED_THRESHOLD) {
            initialBand = "RED";
        } else {
            initialBand = "BLOCK";
        }

        return new DiscountThresholds(
            initialBand,
            Math.max(0, blueMax),
            Math.max(0, yellowMax),
            Math.max(0, redMax),
            Math.max(0, blockAt)
        );
    }

    private static double discountToReachMargin(double salePrice, double purchasePrice, double targetMarginPct) {
        if (targetMarginPct >= 100) return 0;
        double targetPrice = purchasePrice / (1.0 - targetMarginPct / 100.0);
        double discountPct = (1.0 - targetPrice / salePrice) * 100.0;
        return discountPct;
    }
}
