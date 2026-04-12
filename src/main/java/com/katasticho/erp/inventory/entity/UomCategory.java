package com.katasticho.erp.inventory.entity;

/**
 * Classification of a {@link Uom}. Determines which UoMs can be
 * converted into each other via org-wide conversions: you can convert
 * KG → GM (both WEIGHT) but not KG → LTR unless a per-item conversion
 * explicitly defines the density.
 */
public enum UomCategory {
    WEIGHT,
    VOLUME,
    COUNT,
    LENGTH,
    PACKAGING
}
