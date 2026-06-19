package com.katasticho.erp.courier.service;

import java.util.Locale;

/**
 * Translates an aggregator's free-text shipment status (Shiprocket, Delhivery,
 * BlueDart, …) into our canonical {@code CourierShipmentEvent} vocabulary.
 *
 * <p>Aggregators use wildly different phrasings ("Picked Up", "PICKUP DONE",
 * "In Transit", "RTO Delivered", "Undelivered", …) and sometimes numeric codes;
 * this normalises to the fixed set the lifecycle understands. Order matters:
 * RTO is checked before DELIVERED, OUT-FOR-DELIVERY before DELIVERED, so the
 * most-specific phrasing wins.
 *
 * <p>Returns {@code null} for statuses we deliberately ignore (NEW, pickup
 * scheduled, cancelled-by-courier) — the caller skips those rather than forcing
 * a lifecycle change.
 */
public final class CourierStatusMapper {

    private CourierStatusMapper() {}

    /** @return a canonical event status, or {@code null} to ignore. */
    public static String toCanonical(String raw) {
        if (raw == null) return null;
        String s = raw.trim().toUpperCase(Locale.ROOT).replace('-', ' ').replace('_', ' ');
        if (s.isEmpty()) return null;

        // RTO branch first (an RTO status often also contains "delivered"/"transit").
        if (s.contains("RTO")) {
            return s.contains("DELIVERED") ? "RTO_DELIVERED" : "RTO_INITIATED";
        }
        if (s.contains("OUT FOR DELIVERY") || s.contains("OFD")) return "OUT_FOR_DELIVERY";
        // Exception cases first — "UNDELIVERED" contains the substring "DELIVERED".
        if (s.contains("UNDELIVERED") || s.contains("EXCEPTION") || s.contains("ATTEMPT")
                || s.contains("FAILED") || s.contains("LOST") || s.contains("DAMAGED")
                || s.contains("HELD") || s.contains("ON HOLD")) {
            return "EXCEPTION";
        }
        if (s.contains("DELIVERED")) return "DELIVERED";
        if (s.contains("PICKED UP") || s.contains("PICKUP DONE")
                || s.contains("PICKUP COMPLETE") || s.equals("PICKED")) {
            return "PICKED_UP";
        }
        if (s.contains("IN TRANSIT") || s.contains("INTRANSIT") || s.equals("SHIPPED")
                || s.contains("REACHED") || s.contains("DISPATCHED")) {
            return "IN_TRANSIT";
        }
        // NEW / PICKUP SCHEDULED / PICKUP GENERATED / CANCELLED / unknown → ignore.
        return null;
    }
}
