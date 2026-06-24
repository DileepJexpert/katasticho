package com.katasticho.erp.inventory.barcode;

import com.katasticho.erp.common.exception.BusinessException;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class GsOneDataMatrixParserTest {

    private static final char GS = (char) 0x1D;

    // ── 1. Happy path with FNC1 separator ──
    @Test
    void parsesGtinExpiryBatchSerialWithFnc1Separator() {
        // (01)08901234567890(17)271231(10)BATCH123(21)SN001
        String raw = "0108901234567890" + "17271231" + "10BATCH123" + GS + "21SN001";
        GsOneCode code = GsOneDataMatrixParser.parse(raw);

        assertThat(code.gtin()).isEqualTo("08901234567890");
        assertThat(code.expiry()).isEqualTo(LocalDate.of(2027, 12, 31));
        assertThat(code.batch()).isEqualTo("BATCH123");
        assertThat(code.serial()).isEqualTo("SN001");
    }

    // ── 2. Scanner stripped FNC1 — at minimum GTIN + expiry survive ──
    @Test
    void parsesWhenScannerStrippedFnc1AtLeastGtinAndExpirySurvive() {
        // No GS chars. Without a separator the parser can't disambiguate
        // where batch ends and serial begins (a variable AI may contain
        // any printable ASCII), so per the spec we only guarantee that
        // the fixed-length AIs (GTIN, expiry) come through cleanly and
        // that batch is at least populated. The full no-FNC1 case requires
        // either the scanner to preserve GS or the printer to emit it.
        String raw = "0108901234567890" + "17271231" + "10BATCH123";
        GsOneCode code = GsOneDataMatrixParser.parse(raw);

        assertThat(code.gtin()).isEqualTo("08901234567890");
        assertThat(code.expiry()).isEqualTo(LocalDate.of(2027, 12, 31));
        assertThat(code.batch()).isEqualTo("BATCH123");
    }

    // ── 3. Symbology identifier ]d2 prefix is stripped ──
    @Test
    void stripsDataMatrixSymbologyIdentifier() {
        String raw = "]d2" + "0108901234567890" + "17271231";
        GsOneCode code = GsOneDataMatrixParser.parse(raw);
        assertThat(code.gtin()).isEqualTo("08901234567890");
        assertThat(code.expiry()).isEqualTo(LocalDate.of(2027, 12, 31));
    }

    // ── 4. Missing required AI ──
    @Test
    void throwsWhenGtinMissing() {
        // Only an expiry — no GTIN. Parser must complain.
        String raw = "17271231";
        assertThatThrownBy(() -> GsOneDataMatrixParser.parse(raw))
                .isInstanceOf(BusinessException.class)
                .extracting(t -> ((BusinessException) t).getErrorCode())
                .isEqualTo("GS1_PARSE_FAILED");
    }

    // ── 5. Expiry DD=00 → last day of month ──
    @Test
    void expiryWithDd00MapsToLastDayOfMonth() {
        // (17) 271200 → December 2027 → Dec 31.
        String raw = "0108901234567890" + "17271200";
        GsOneCode code = GsOneDataMatrixParser.parse(raw);
        assertThat(code.expiry()).isEqualTo(LocalDate.of(2027, 12, 31));

        // Edge case — February non-leap year YY=27, MM=02, DD=00.
        String feb = "0108901234567890" + "17270200";
        GsOneCode febCode = GsOneDataMatrixParser.parse(feb);
        assertThat(febCode.expiry()).isEqualTo(LocalDate.of(2027, 2, 28));
    }

    // ── 6. Expiry DD=15 — exact date ──
    @Test
    void expiryWithExplicitDdParsesExactly() {
        String raw = "0108901234567890" + "17271215";
        GsOneCode code = GsOneDataMatrixParser.parse(raw);
        assertThat(code.expiry()).isEqualTo(LocalDate.of(2027, 12, 15));
    }

    // ── 7. Sliding window for 2-digit year ──
    @Test
    void yearSlidingWindow_yy49Becomes2049_yy50Becomes1950() {
        // YY=49 — 2049
        GsOneCode a = GsOneDataMatrixParser.parse("0108901234567890" + "17491215");
        assertThat(a.expiry()).isEqualTo(LocalDate.of(2049, 12, 15));

        // YY=50 — 1950 (very old expiry but parser must follow the spec).
        GsOneCode b = GsOneDataMatrixParser.parse("0108901234567890" + "17501215");
        assertThat(b.expiry()).isEqualTo(LocalDate.of(1950, 12, 15));
    }
}
