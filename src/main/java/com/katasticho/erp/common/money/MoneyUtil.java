package com.katasticho.erp.common.money;

import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * Currency-aware money rounding. The codebase historically hardcodes
 * {@code setScale(2, HALF_UP)} in ~100 posting sites — correct for INR/AED/KES
 * (2dp) but wrong for the Gulf dinars OMR/BHD/KWD (3dp) and JPY (0dp).
 *
 * <p>This is the central helper those sites migrate to. Until the full sweep
 * (deferred to the Oman phase — the UAE beachhead is 2dp and unaffected), it
 * exists so new code rounds correctly by currency from day one.
 *
 * <p>Always HALF_UP — the convention every existing posting site uses, so
 * migrating a 2dp site to {@code round(x, 2)} is byte-for-byte identical.
 */
public final class MoneyUtil {

    private MoneyUtil() {}

    /** Round to the given number of decimal places, HALF_UP. */
    public static BigDecimal round(BigDecimal amount, int decimals) {
        if (amount == null) return null;
        return amount.setScale(decimals, RoundingMode.HALF_UP);
    }

    /**
     * Round for posting using a currency's minor-unit precision.
     * Byte-identical to {@code setScale(2)} when {@code decimals == 2}.
     */
    public static BigDecimal roundForPosting(BigDecimal amount, int decimals) {
        return round(amount, decimals);
    }
}
