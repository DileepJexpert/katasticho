package com.katasticho.erp.recurring.entity;

import java.time.LocalDate;

/**
 * Billing cadence for a recurring invoice template. The enum
 * owns the "advance next_invoice_date by one cycle" math so the
 * scheduler doesn't have to duplicate a switch.
 */
public enum RecurringFrequency {
    WEEKLY,
    MONTHLY,
    QUARTERLY,
    HALF_YEARLY,
    YEARLY;

    public LocalDate advance(LocalDate from) {
        return switch (this) {
            case WEEKLY      -> from.plusWeeks(1);
            case MONTHLY     -> from.plusMonths(1);
            case QUARTERLY   -> from.plusMonths(3);
            case HALF_YEARLY -> from.plusMonths(6);
            case YEARLY      -> from.plusYears(1);
        };
    }
}
