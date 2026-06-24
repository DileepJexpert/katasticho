package com.katasticho.erp.inventory.barcode;

import com.katasticho.erp.common.exception.BusinessException;
import org.springframework.http.HttpStatus;

import java.time.LocalDate;
import java.util.Set;

/**
 * Parser for GS1 DataMatrix codes printed on top-300 pharma packs (CDSCO
 * G.S.R. 823(E)). Handles:
 * <ul>
 *   <li><b>Fixed-length AIs:</b> (01) GTIN — 14 digits, (17) expiry —
 *       YYMMDD, (11) MFG date — YYMMDD.</li>
 *   <li><b>Variable-length AIs:</b> (10) batch, (21) serial, (240) additional —
 *       terminated by FNC1 (0x1D / GS) or end-of-string.</li>
 *   <li>Leading symbology identifier {@code ]d2} (DataMatrix profile) — stripped.</li>
 *   <li>Scanner-stripped FNC1: greedy fallback splits at the next known AI
 *       prefix when no GS character is present.</li>
 *   <li>2-digit year: 00-49 → 2000+YY, 50-99 → 1900+YY (GS1 sliding window).</li>
 *   <li>Expiry DD=00 → last day of month (GS1 convention).</li>
 * </ul>
 *
 * <p>Pure utility — NOT a Spring bean. State-free, thread-safe.
 */
public final class GsOneDataMatrixParser {

    private static final char FNC1 = (char) 0x1D;
    private static final String SYMBOLOGY_DATAMATRIX = "]d2";

    /** Known AIs the parser understands. Used by the no-FNC1 fallback. */
    private static final Set<String> KNOWN_AIS = Set.of("01", "10", "11", "17", "21", "240");

    private GsOneDataMatrixParser() {
        // no instances
    }

    public static GsOneCode parse(String raw) {
        if (raw == null || raw.isEmpty()) {
            throw fail("Empty barcode");
        }
        // Strip the DataMatrix symbology identifier scanners sometimes prepend.
        String input = raw;
        if (input.startsWith(SYMBOLOGY_DATAMATRIX)) {
            input = input.substring(SYMBOLOGY_DATAMATRIX.length());
        }
        // When at least one FNC1 is present the parser respects it — a
        // variable AI without a trailing GS runs to end of string (it was
        // the last AI). When NO FNC1 appears anywhere, the scanner stripped
        // them all and we fall back to greedy AI-prefix detection.
        boolean hasFnc1 = input.indexOf(FNC1) >= 0;

        String gtin = null;
        String batch = null;
        LocalDate expiry = null;
        String serial = null;
        LocalDate mfgDate = null;

        int i = 0;
        while (i < input.length()) {
            // Skip stray FNC1 between fields (some scanners pile them).
            if (input.charAt(i) == FNC1) {
                i++;
                continue;
            }
            if (i + 2 > input.length()) {
                // Trailing garbage — accept what we have.
                break;
            }
            String ai = input.substring(i, i + 2);
            int valueStart = i + 2;

            switch (ai) {
                case "01" -> {
                    if (valueStart + 14 > input.length()) {
                        throw fail("AI (01) GTIN truncated");
                    }
                    gtin = input.substring(valueStart, valueStart + 14);
                    if (!gtin.chars().allMatch(Character::isDigit)) {
                        throw fail("AI (01) GTIN is non-numeric: " + gtin);
                    }
                    i = valueStart + 14;
                }
                case "17" -> {
                    if (valueStart + 6 > input.length()) {
                        throw fail("AI (17) expiry truncated");
                    }
                    String yyMMdd = input.substring(valueStart, valueStart + 6);
                    expiry = parseDate(yyMMdd, "expiry", true);
                    i = valueStart + 6;
                }
                case "11" -> {
                    if (valueStart + 6 > input.length()) {
                        throw fail("AI (11) MFG date truncated");
                    }
                    String yyMMdd = input.substring(valueStart, valueStart + 6);
                    mfgDate = parseDate(yyMMdd, "MFG", false);
                    i = valueStart + 6;
                }
                case "10" -> {
                    int end = findEndOfVariable(input, valueStart, hasFnc1);
                    batch = input.substring(valueStart, end);
                    i = end;
                }
                case "21" -> {
                    int end = findEndOfVariable(input, valueStart, hasFnc1);
                    serial = input.substring(valueStart, end);
                    i = end;
                }
                case "240" -> {
                    // (240) is actually 3-digit AI; rewrite valueStart.
                    if (i + 3 > input.length()) throw fail("AI (240) truncated");
                    int end = findEndOfVariable(input, i + 3, hasFnc1);
                    // Read but don't expose — we don't store additional ids
                    // on GsOneCode today. Skipping is intentional.
                    i = end;
                }
                default -> throw fail("Unrecognised GS1 AI '" + ai + "' at position " + i);
            }
        }

        if (gtin == null) {
            throw fail("Missing AI (01) GTIN — not a valid GS1 DataMatrix pharma code");
        }
        return new GsOneCode(gtin, batch, expiry, serial, mfgDate);
    }

    private static int findEndOfVariable(String input, int from, boolean hasFnc1) {
        if (hasFnc1) {
            // GS is the authoritative separator when the scanner preserves
            // it. No GS at or after `from` means this variable AI is the
            // LAST AI in the payload.
            int gs = input.indexOf(FNC1, from);
            return gs >= 0 ? gs : input.length();
        }

        // No FNC1 anywhere — scanner stripped them all. Fall back to a
        // structure-aware greedy scan: a candidate AI boundary only counts
        // when the bytes that follow it match the FIXED-LENGTH AI's shape
        // (numeric, exact length). Without this constraint the scanner sees
        // "01" in a serial like "SN001" and mistakes it for the next GTIN.
        // Variable AIs (10 / 21 / 240) inside a previous variable AI's
        // content are still ambiguous, so we never auto-break on them in
        // greedy mode — the previous variable AI runs to end of input.
        for (int p = from + 1; p + 2 <= input.length(); p++) {
            String maybeAi = input.substring(p, p + 2);
            if ("01".equals(maybeAi) && looksLikeNumericRun(input, p + 2, 14)) return p;
            if (("17".equals(maybeAi) || "11".equals(maybeAi))
                    && looksLikeNumericRun(input, p + 2, 6)) return p;
        }
        // No further AI found — variable AI runs to end of string.
        return input.length();
    }

    private static boolean looksLikeNumericRun(String s, int start, int len) {
        if (start + len > s.length()) return false;
        for (int k = start; k < start + len; k++) {
            if (!Character.isDigit(s.charAt(k))) return false;
        }
        return true;
    }

    private static LocalDate parseDate(String yyMMdd, String label, boolean ddZeroIsLastOfMonth) {
        if (yyMMdd.length() != 6 || !yyMMdd.chars().allMatch(Character::isDigit)) {
            throw fail("AI " + label + " date is non-numeric: " + yyMMdd);
        }
        int yy = Integer.parseInt(yyMMdd.substring(0, 2));
        int mm = Integer.parseInt(yyMMdd.substring(2, 4));
        int dd = Integer.parseInt(yyMMdd.substring(4, 6));
        // GS1 sliding window for 2-digit year.
        int year = yy < 50 ? 2000 + yy : 1900 + yy;
        if (mm < 1 || mm > 12) throw fail("AI " + label + " month out of range: " + mm);

        if (dd == 0 && ddZeroIsLastOfMonth) {
            // GS1 convention: expiry with DD=00 means last day of the month.
            return LocalDate.of(year, mm, 1).withDayOfMonth(
                    LocalDate.of(year, mm, 1).lengthOfMonth());
        }
        if (dd < 1 || dd > 31) throw fail("AI " + label + " day out of range: " + dd);
        try {
            return LocalDate.of(year, mm, dd);
        } catch (Exception e) {
            throw fail("AI " + label + " date invalid: " + yyMMdd);
        }
    }

    private static BusinessException fail(String message) {
        return new BusinessException(
                "Invalid GS1 DataMatrix code: " + message,
                "GS1_PARSE_FAILED", HttpStatus.BAD_REQUEST);
    }
}
