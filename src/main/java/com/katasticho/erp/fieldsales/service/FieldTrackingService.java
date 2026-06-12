package com.katasticho.erp.fieldsales.service;

import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.fieldsales.entity.FieldLocationPing;
import com.katasticho.erp.fieldsales.repository.FieldLocationPingRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Live GPS tracking for field salespeople: breadcrumb pings during route
 * execution, latest-location snapshot for admins, and per-execution trail
 * with travelled distance. Read alongside {@link FieldSalesService}, which
 * owns visits/check-ins; geofence verification at check-in uses
 * {@link #distanceMeters} from here.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class FieldTrackingService {

    private static final int MAX_BATCH_SIZE = 500;

    private final FieldLocationPingRepository pingRepository;
    private final AppUserRepository appUserRepository;

    /** One GPS sample sent by the field app. */
    public record PingRequest(BigDecimal latitude, BigDecimal longitude,
                              BigDecimal accuracyM, Instant recordedAt,
                              UUID routeExecutionId) {}

    /**
     * Records a batch of GPS pings for the current user. Batched so the
     * field app can buffer offline and flush on reconnect.
     */
    @Transactional
    public List<FieldLocationPing> recordPings(List<PingRequest> pings) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID salespersonId = TenantContext.getCurrentUserId();

        if (pings == null || pings.isEmpty()) {
            throw new BusinessException("No pings provided", "FS_PING_EMPTY", HttpStatus.BAD_REQUEST);
        }
        if (pings.size() > MAX_BATCH_SIZE) {
            throw new BusinessException("Ping batch exceeds " + MAX_BATCH_SIZE,
                    "FS_PING_BATCH_TOO_LARGE", HttpStatus.BAD_REQUEST);
        }

        List<FieldLocationPing> rows = new ArrayList<>();
        for (PingRequest p : pings) {
            if (p.latitude() == null || p.longitude() == null) {
                throw new BusinessException("Ping latitude/longitude required",
                        "FS_PING_INVALID", HttpStatus.BAD_REQUEST);
            }
            rows.add(FieldLocationPing.builder()
                    .orgId(orgId)
                    .salespersonId(salespersonId)
                    .routeExecutionId(p.routeExecutionId())
                    .latitude(p.latitude())
                    .longitude(p.longitude())
                    .accuracyM(p.accuracyM())
                    .recordedAt(p.recordedAt() != null ? p.recordedAt() : Instant.now())
                    .build());
        }
        rows = pingRepository.saveAll(rows);
        log.debug("Recorded {} location pings for salesperson {} org {}", rows.size(), salespersonId, orgId);
        return rows;
    }

    /**
     * Latest location of every salesperson who pinged today (UTC day),
     * with the user's name resolved for the live map/list.
     */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> liveLocations() {
        UUID orgId = TenantContext.getCurrentOrgId();
        Instant since = LocalDate.now(ZoneOffset.UTC).atStartOfDay().toInstant(ZoneOffset.UTC);

        List<FieldLocationPing> latest = pingRepository.findLatestPerSalesperson(orgId, since);
        Set<UUID> userIds = latest.stream().map(FieldLocationPing::getSalespersonId).collect(Collectors.toSet());
        Map<UUID, String> names = appUserRepository.findAllById(userIds).stream()
                .collect(Collectors.toMap(AppUser::getId, u -> u.getFullName() != null ? u.getFullName() : ""));

        List<Map<String, Object>> result = new ArrayList<>();
        for (FieldLocationPing ping : latest) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("salespersonId", ping.getSalespersonId());
            row.put("salespersonName", names.getOrDefault(ping.getSalespersonId(), ""));
            row.put("latitude", ping.getLatitude());
            row.put("longitude", ping.getLongitude());
            row.put("accuracyM", ping.getAccuracyM());
            row.put("recordedAt", ping.getRecordedAt());
            row.put("routeExecutionId", ping.getRouteExecutionId());
            result.add(row);
        }
        return result;
    }

    /**
     * Breadcrumb trail for a route execution plus total travelled distance
     * (sum of haversine hops between consecutive pings).
     */
    @Transactional(readOnly = true)
    public Map<String, Object> trail(UUID routeExecutionId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<FieldLocationPing> pings =
                pingRepository.findByOrgIdAndRouteExecutionIdOrderByRecordedAtAsc(orgId, routeExecutionId);

        double totalMeters = 0;
        for (int i = 1; i < pings.size(); i++) {
            totalMeters += distanceMeters(
                    pings.get(i - 1).getLatitude(), pings.get(i - 1).getLongitude(),
                    pings.get(i).getLatitude(), pings.get(i).getLongitude());
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("routeExecutionId", routeExecutionId);
        result.put("pingCount", pings.size());
        result.put("totalDistanceKm", BigDecimal.valueOf(totalMeters / 1000.0)
                .setScale(2, RoundingMode.HALF_UP));
        result.put("pings", pings);
        return result;
    }

    /** Haversine distance in meters between two coordinates. */
    public static double distanceMeters(BigDecimal lat1, BigDecimal lon1,
                                        BigDecimal lat2, BigDecimal lon2) {
        double phi1 = Math.toRadians(lat1.doubleValue());
        double phi2 = Math.toRadians(lat2.doubleValue());
        double dPhi = Math.toRadians(lat2.subtract(lat1).doubleValue());
        double dLambda = Math.toRadians(lon2.subtract(lon1).doubleValue());

        double a = Math.sin(dPhi / 2) * Math.sin(dPhi / 2)
                + Math.cos(phi1) * Math.cos(phi2) * Math.sin(dLambda / 2) * Math.sin(dLambda / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return 6371000.0 * c;
    }
}
