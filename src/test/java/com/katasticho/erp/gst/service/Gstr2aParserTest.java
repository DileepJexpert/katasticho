package com.katasticho.erp.gst.service;

import com.katasticho.erp.gst.entity.Gstr2bEntry;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class Gstr2aParserTest {

    private final Gstr2aParser parser = new Gstr2aParser();
    private final UUID orgId = UUID.randomUUID();

    @Test
    void parses2aShape_iamtKeys_nestedItmDet_dataB2b() {
        // Real GSTR-2A: data.b2b, tax under itm_det as iamt/camt/samt/csamt.
        Map<String, Object> json = Map.of("data", Map.of("b2b", List.of(
                Map.of(
                        "ctin", "27AABCT1234A1Z5",
                        "trdnm", "ABC Pharma",
                        "cfs", "Y",
                        "inv", List.of(Map.of(
                                "inum", "INV-001",
                                "dt", "05-05-2026",
                                "val", 1064,
                                "itms", List.of(Map.of(
                                        "num", 1,
                                        "itm_det", Map.of(
                                                "txval", 950, "rt", 12,
                                                "iamt", 0, "camt", 57, "samt", 57, "csamt", 0)))
                        ))
                ))));

        List<Gstr2bEntry> parsed = parser.parse(orgId, "2026-05", json);

        assertThat(parsed).hasSize(1);
        Gstr2bEntry e = parsed.get(0);
        assertThat(e.getSupplierGstin()).isEqualTo("27AABCT1234A1Z5");
        assertThat(e.getInvoiceNumber()).isEqualTo("INV-001");
        assertThat(e.getInvoiceDate()).isEqualTo(LocalDate.of(2026, 5, 5));
        assertThat(e.getTaxableValue()).isEqualByComparingTo("950");
        assertThat(e.getCgst()).isEqualByComparingTo("57"); // from camt
        assertThat(e.getSgst()).isEqualByComparingTo("57"); // from samt
        assertThat(e.totalTax()).isEqualByComparingTo("114");
        assertThat(e.isItcAvailable()).isTrue();
    }

    @Test
    void tolerates_topLevelB2b_andFlatItemTax() {
        // Some GSPs flatten: b2b at top level, tax fields directly on the item.
        Map<String, Object> json = Map.of("b2b", List.of(
                Map.of(
                        "ctin", "29ZZZZZ9999Z1Z5",
                        "inv", List.of(Map.of(
                                "inum", "B-7",
                                "val", 11800,
                                "itms", List.of(Map.of(
                                        "txval", 10000, "iamt", 1800, "camt", 0, "samt", 0))))
                )));

        List<Gstr2bEntry> parsed = parser.parse(orgId, "2026-05", json);

        assertThat(parsed).hasSize(1);
        assertThat(parsed.get(0).getIgst()).isEqualByComparingTo("1800"); // from flat iamt
        assertThat(parsed.get(0).totalTax()).isEqualByComparingTo("1800");
    }

    @Test
    void emptyOrUnknownShape_returnsEmpty() {
        assertThat(parser.parse(orgId, "2026-05", null)).isEmpty();
        assertThat(parser.parse(orgId, "2026-05", Map.of("data", Map.of()))).isEmpty();
    }
}
