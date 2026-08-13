package com.katasticho.erp.fieldsales.dto;

import java.util.UUID;

/** Lightweight aggregate used when rendering the route planning list. */
public interface RouteBeatCountProjection {

    UUID getRouteId();

    long getBeatCount();
}
