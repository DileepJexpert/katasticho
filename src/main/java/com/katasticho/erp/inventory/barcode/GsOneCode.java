package com.katasticho.erp.inventory.barcode;

import java.time.LocalDate;

/**
 * Parsed GS1 DataMatrix payload — populated by {@link GsOneDataMatrixParser}.
 *
 * <p>Every field is optional; the GS1 spec doesn't require every AI in every
 * scan, and a scanner may strip the FNC1 separators that delimit variable-
 * length AIs, in which case only the fixed-length AIs (GTIN / expiry / MFG)
 * are guaranteed to come through cleanly.
 */
public record GsOneCode(
        String gtin,
        String batch,
        LocalDate expiry,
        String serial,
        LocalDate mfgDate
) {}
