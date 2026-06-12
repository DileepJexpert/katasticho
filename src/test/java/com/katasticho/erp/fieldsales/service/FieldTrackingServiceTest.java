package com.katasticho.erp.fieldsales.service;

import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.fieldsales.entity.FieldLocationPing;
import com.katasticho.erp.fieldsales.repository.FieldLocationPingRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class FieldTrackingServiceTest {

    @Mock private FieldLocationPingRepository pingRepo;
    @Mock private AppUserRepository appUserRepo;

    private FieldTrackingService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new FieldTrackingService(pingRepo, appUserRepo);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void recordPings_stampsOrgAndSalesperson() {
        when(pingRepo.saveAll(any())).thenAnswer(inv -> inv.getArgument(0));

        UUID execId = UUID.randomUUID();
        List<FieldLocationPing> saved = service.recordPings(List.of(
                new FieldTrackingService.PingRequest(
                        new BigDecimal("28.6139"), new BigDecimal("77.2090"),
                        new BigDecimal("12.5"), Instant.parse("2026-06-12T09:00:00Z"), execId),
                new FieldTrackingService.PingRequest(
                        new BigDecimal("28.6150"), new BigDecimal("77.2095"),
                        null, null, execId)));

        assertEquals(2, saved.size());
        for (FieldLocationPing p : saved) {
            assertEquals(orgId, p.getOrgId());
            assertEquals(userId, p.getSalespersonId());
            assertEquals(execId, p.getRouteExecutionId());
            assertNotNull(p.getRecordedAt());
        }
    }

    @Test
    void recordPings_emptyBatch_throws() {
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.recordPings(List.of()));
        assertEquals("FS_PING_EMPTY", ex.getErrorCode());
    }

    @Test
    void recordPings_missingCoordinates_throws() {
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.recordPings(List.of(new FieldTrackingService.PingRequest(
                        null, new BigDecimal("77.2090"), null, null, null))));
        assertEquals("FS_PING_INVALID", ex.getErrorCode());
    }

    @Test
    void trail_sumsDistanceBetweenConsecutivePings() {
        UUID execId = UUID.randomUUID();
        // Two hops of ~1.11km each (0.01 deg latitude apart)
        when(pingRepo.findByOrgIdAndRouteExecutionIdOrderByRecordedAtAsc(orgId, execId))
                .thenReturn(List.of(
                        ping("28.6000", "77.2000"),
                        ping("28.6100", "77.2000"),
                        ping("28.6200", "77.2000")));

        Map<String, Object> trail = service.trail(execId);

        assertEquals(3, trail.get("pingCount"));
        double km = ((BigDecimal) trail.get("totalDistanceKm")).doubleValue();
        assertTrue(km > 2.0 && km < 2.5, "expected ~2.2km, got " + km);
    }

    @Test
    void trail_noPings_zeroDistance() {
        UUID execId = UUID.randomUUID();
        when(pingRepo.findByOrgIdAndRouteExecutionIdOrderByRecordedAtAsc(orgId, execId))
                .thenReturn(List.of());

        Map<String, Object> trail = service.trail(execId);

        assertEquals(0, trail.get("pingCount"));
        assertEquals(0, ((BigDecimal) trail.get("totalDistanceKm")).compareTo(BigDecimal.ZERO));
    }

    @Test
    void liveLocations_returnsLatestPerSalesperson() {
        FieldLocationPing latest = ping("28.6139", "77.2090");
        latest.setSalespersonId(userId);
        when(pingRepo.findLatestPerSalesperson(eq(orgId), any())).thenReturn(List.of(latest));
        when(appUserRepo.findAllById(any())).thenReturn(List.of());

        List<Map<String, Object>> live = service.liveLocations();

        assertEquals(1, live.size());
        assertEquals(userId, live.get(0).get("salespersonId"));
        assertEquals(new BigDecimal("28.6139"), live.get(0).get("latitude"));
    }

    @Test
    void distanceMeters_knownDistance() {
        // 0.01 degrees of latitude ≈ 1111 meters
        double d = FieldTrackingService.distanceMeters(
                new BigDecimal("28.6000"), new BigDecimal("77.2000"),
                new BigDecimal("28.6100"), new BigDecimal("77.2000"));
        assertTrue(d > 1100 && d < 1125, "expected ~1111m, got " + d);
    }

    private FieldLocationPing ping(String lat, String lng) {
        return FieldLocationPing.builder()
                .orgId(orgId).salespersonId(userId)
                .latitude(new BigDecimal(lat)).longitude(new BigDecimal(lng))
                .recordedAt(Instant.now())
                .build();
    }
}
