package com.katasticho.erp.pharma.register;

/**
 * Statutory pharma register classifications under the Drugs & Cosmetics Rules.
 *
 * <p>Each register has a distinct retention horizon and inspector form lineage:
 * <ul>
 *   <li>{@link #H1} — Schedule H1 antibiotics + narrowed list per Rule 65(11)(h),
 *       3-year retention.</li>
 *   <li>{@link #SCHEDULE_X} — Form 20G holders' restricted psychotropics,
 *       2-year retention.</li>
 *   <li>{@link #NARCOTICS} — NDPS Forms 3D/3E/3H, ≥2-year retention.</li>
 * </ul>
 */
public enum RegisterType {
    H1,
    SCHEDULE_X,
    NARCOTICS;

    /** Years to retain entries of this register type from sale date. */
    public int retentionYears() {
        return this == H1 ? 3 : 2;
    }
}
