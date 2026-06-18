package com.katasticho.erp.courier.service;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;

/**
 * Tolerant extraction of {AWB, status, timestamp, location} from an aggregator's
 * tracking JSON — handles both the flat webhook shape Shiprocket pushes
 * ({@code current_status} + {@code awb}) and the nested track-API shape
 * ({@code tracking_data.shipment_track[].current_status}). Unknown shapes yield
 * an update with null fields, which the caller ignores.
 */
public final class TrackingPayloadParser {

    private TrackingPayloadParser() {}

    public record TrackingUpdate(String awb, String statusRaw, Instant eventAt, String location) {
        public boolean usable() {
            return statusRaw != null && !statusRaw.isBlank();
        }
    }

    private static final DateTimeFormatter[] DATE_FORMATS = {
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"),
            DateTimeFormatter.ofPattern("dd-MM-yyyy HH:mm:ss"),
            DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss"),
    };

    @SuppressWarnings("unchecked")
    public static TrackingUpdate parse(Map<String, Object> json) {
        if (json == null) return new TrackingUpdate(null, null, null, null);

        // Nested Shiprocket track-API: data.tracking_data.shipment_track[0]
        Object data = json.getOrDefault("data", json);
        Map<String, Object> root = data instanceof Map ? (Map<String, Object>) data : json;
        Object trackingData = root.get("tracking_data");
        if (trackingData instanceof Map<?, ?> td) {
            Object track = ((Map<String, Object>) td).get("shipment_track");
            if (track instanceof List<?> list && !list.isEmpty()
                    && list.get(0) instanceof Map<?, ?> first) {
                Map<String, Object> t = (Map<String, Object>) first;
                String awb = str(t, "awb_code", "awb");
                String status = str(t, "current_status", "status");
                String loc = str(t, "current_location", "location", "destination");
                Instant at = firstDate(t, "updated_time_stamp", "current_timestamp", "edd");
                // Pull a fresher activity timestamp/location if present.
                Object acts = ((Map<String, Object>) td).get("shipment_track_activities");
                if (acts instanceof List<?> al && !al.isEmpty()
                        && al.get(0) instanceof Map<?, ?> a0) {
                    Map<String, Object> a = (Map<String, Object>) a0;
                    if (at == null) at = firstDate(a, "date");
                    if (loc == null) loc = str(a, "location");
                    if (status == null) status = str(a, "status", "activity", "sr_status_label");
                }
                return new TrackingUpdate(awb, status, at, loc);
            }
        }

        // Flat webhook shape.
        String awb = str(root, "awb", "awb_code", "waybill");
        String status = str(root, "current_status", "status", "shipment_status", "sr_status_label");
        String loc = str(root, "current_location", "location", "destination");
        Instant at = firstDate(root, "current_timestamp", "updated_at", "timestamp", "date");
        return new TrackingUpdate(awb, status, at, loc);
    }

    private static String str(Map<String, Object> m, String... keys) {
        for (String k : keys) {
            Object v = m.get(k);
            if (v != null) {
                String s = v.toString().trim();
                if (!s.isEmpty() && !"null".equalsIgnoreCase(s)) return s;
            }
        }
        return null;
    }

    private static Instant firstDate(Map<String, Object> m, String... keys) {
        for (String k : keys) {
            Object v = m.get(k);
            if (v == null) continue;
            String s = v.toString().trim();
            if (s.isEmpty()) continue;
            for (DateTimeFormatter f : DATE_FORMATS) {
                try {
                    return LocalDateTime.parse(s, f).toInstant(ZoneOffset.UTC);
                } catch (Exception ignored) { /* try next */ }
            }
            try {
                return Instant.parse(s);
            } catch (Exception ignored) { /* not ISO instant */ }
        }
        return null;
    }
}
