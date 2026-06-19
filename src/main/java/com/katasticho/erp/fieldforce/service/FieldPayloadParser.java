package com.katasticho.erp.fieldforce.service;

import com.katasticho.erp.fieldsales.service.FieldTrackingService;
import com.katasticho.erp.sales.dto.SalesOrderLineRequest;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** Shared map→DTO parsing for the field facade (used by the controller and sync). */
public final class FieldPayloadParser {

    private FieldPayloadParser() {}

    @SuppressWarnings("unchecked")
    public static List<SalesOrderLineRequest> parseLines(Object raw) {
        List<SalesOrderLineRequest> lines = new ArrayList<>();
        if (!(raw instanceof List<?> list)) return lines;
        for (Object o : list) {
            Map<String, Object> m = (Map<String, Object>) o;
            lines.add(new SalesOrderLineRequest(
                    uuid(m.get("itemId")),
                    (String) m.get("description"),
                    num(m.get("quantity")),
                    num(m.get("rate")),
                    (String) m.get("unit"),
                    num(m.get("discountPct")),
                    uuid(m.get("taxGroupId")),
                    (String) m.get("hsnCode")));
        }
        return lines;
    }

    @SuppressWarnings("unchecked")
    public static List<FieldTrackingService.PingRequest> parsePings(Object raw) {
        List<FieldTrackingService.PingRequest> pings = new ArrayList<>();
        if (!(raw instanceof List<?> list)) return pings;
        for (Object o : list) {
            Map<String, Object> p = (Map<String, Object>) o;
            pings.add(new FieldTrackingService.PingRequest(
                    num(p.get("latitude")), num(p.get("longitude")), num(p.get("accuracyM")),
                    p.get("recordedAt") != null ? Instant.parse(p.get("recordedAt").toString()) : null,
                    uuid(p.get("routeExecutionId"))));
        }
        return pings;
    }

    public static BigDecimal num(Object o) {
        if (o == null) return null;
        if (o instanceof Number n) return new BigDecimal(n.toString());
        try {
            return new BigDecimal(o.toString());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    public static UUID uuid(Object o) {
        return o == null ? null : UUID.fromString(o.toString());
    }
}
