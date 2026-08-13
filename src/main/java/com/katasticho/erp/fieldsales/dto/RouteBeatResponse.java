package com.katasticho.erp.fieldsales.dto;

import java.util.UUID;

/** A route stop enriched with the beat details needed by route planning screens. */
public record RouteBeatResponse(
        UUID id,
        UUID routeId,
        UUID beatId,
        String beatCode,
        String beatName,
        String area,
        String city,
        Integer sequenceNumber) {
}
