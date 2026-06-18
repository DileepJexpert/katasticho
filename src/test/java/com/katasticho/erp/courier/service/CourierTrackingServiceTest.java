package com.katasticho.erp.courier.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.courier.dto.CourierShipmentDtos.RecordEventRequest;
import com.katasticho.erp.courier.entity.CourierShipment;
import com.katasticho.erp.courier.repository.CourierShipmentRepository;
import com.katasticho.erp.organisation.OrgSetting;
import com.katasticho.erp.organisation.OrgSettingsRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class CourierTrackingServiceTest {

    @Mock private CourierShipmentRepository shipmentRepository;
    @Mock private CourierShipmentService shipmentService;
    @Mock private CourierClient courierClient;
    @Mock private CodReconciliationService codReconciliationService;
    @Mock private OrgSettingsRepository orgSettingsRepository;
    private CourierTrackingService service;

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new CourierTrackingService(shipmentRepository, shipmentService,
                courierClient, codReconciliationService, orgSettingsRepository);
        TenantContext.setCurrentOrgId(orgId);
    }

    @AfterEach
    void tearDown() { TenantContext.clear(); }

    private CourierShipment shipment(String awb, String status) {
        CourierShipment s = CourierShipment.builder()
                .courierPartner("SHIPROCKET").awbNumber(awb).status(status).build();
        s.setId(UUID.randomUUID());
        s.setOrgId(orgId);
        return s;
    }

    @Test
    void applyTracking_advancesStatus_recordsEvent() {
        CourierShipment s = shipment("AWB1", "IN_TRANSIT");
        when(shipmentRepository.findFirstByOrgIdAndCourierPartnerAndAwbNumberAndIsDeletedFalse(
                orgId, "SHIPROCKET", "AWB1")).thenReturn(Optional.of(s));

        boolean applied = service.applyTracking("SHIPROCKET", "AWB1", "Out For Delivery",
                Instant.now(), "Hub-DEL", null, "POLL");

        assertThat(applied).isTrue();
        ArgumentCaptor<RecordEventRequest> cap = ArgumentCaptor.forClass(RecordEventRequest.class);
        verify(shipmentService).recordEvent(eq(s.getId()), cap.capture());
        assertThat(cap.getValue().eventStatus()).isEqualTo("OUT_FOR_DELIVERY");
        assertThat(cap.getValue().source()).isEqualTo("POLL");
    }

    @Test
    void applyTracking_sameStatus_isNoOp() {
        CourierShipment s = shipment("AWB1", "IN_TRANSIT");
        when(shipmentRepository.findFirstByOrgIdAndCourierPartnerAndAwbNumberAndIsDeletedFalse(
                orgId, "SHIPROCKET", "AWB1")).thenReturn(Optional.of(s));

        boolean applied = service.applyTracking("SHIPROCKET", "AWB1", "In Transit",
                Instant.now(), null, null, "POLL");

        assertThat(applied).isFalse();
        verify(shipmentService, never()).recordEvent(any(), any());
    }

    @Test
    void applyTracking_terminalShipment_neverMoves() {
        CourierShipment s = shipment("AWB1", "DELIVERED");
        when(shipmentRepository.findFirstByOrgIdAndCourierPartnerAndAwbNumberAndIsDeletedFalse(
                orgId, "SHIPROCKET", "AWB1")).thenReturn(Optional.of(s));

        // A late "In Transit" scan must not regress a delivered parcel.
        assertThat(service.applyTracking("SHIPROCKET", "AWB1", "In Transit",
                Instant.now(), null, null, "WEBHOOK")).isFalse();
        verify(shipmentService, never()).recordEvent(any(), any());
    }

    @Test
    void applyTracking_unknownStatus_orNoShipment_isSkipped() {
        when(shipmentRepository.findFirstByOrgIdAndCourierPartnerAndAwbNumberAndIsDeletedFalse(
                any(), any(), any())).thenReturn(Optional.empty());
        when(shipmentRepository.findFirstByOrgIdAndAwbNumberAndIsDeletedFalse(any(), any()))
                .thenReturn(Optional.empty());

        assertThat(service.applyTracking("SHIPROCKET", "AWB-X", "Pickup Scheduled",
                Instant.now(), null, null, "POLL")).isFalse();        // ignored status
        assertThat(service.applyTracking("SHIPROCKET", "AWB-X", "Delivered",
                Instant.now(), null, null, "POLL")).isFalse();        // no shipment
    }

    @Test
    void ingestWebhook_parsesFlatPayloadAndApplies() {
        CourierShipment s = shipment("AWB9", "IN_TRANSIT");
        when(shipmentRepository.findFirstByOrgIdAndCourierPartnerAndAwbNumberAndIsDeletedFalse(
                orgId, "SHIPROCKET", "AWB9")).thenReturn(Optional.of(s));

        boolean applied = service.ingestWebhook("SHIPROCKET", Map.of(
                "awb", "AWB9",
                "current_status", "Delivered",
                "current_timestamp", "2026-06-17 14:30:00"));

        assertThat(applied).isTrue();
        verify(shipmentService).recordEvent(eq(s.getId()), argThat(r ->
                r.eventStatus().equals("DELIVERED") && r.source().equals("WEBHOOK")));
    }

    @Test
    void resolveOrgByWebhookToken_looksUpSetting() {
        OrgSetting setting = OrgSetting.builder().orgId(orgId)
                .key("courier.shiprocket.webhook_token").value("cwh_abc").build();
        when(orgSettingsRepository.findFirstByKeyAndValue("courier.shiprocket.webhook_token", "cwh_abc"))
                .thenReturn(Optional.of(setting));

        assertThat(service.resolveOrgByWebhookToken("SHIPROCKET", "cwh_abc")).contains(orgId);
        assertThat(service.resolveOrgByWebhookToken("SHIPROCKET", "wrong")).isEmpty();
    }

    @Test
    void syncOrg_skipsTerminalAndUnconfigured() {
        CourierShipment inFlight = shipment("AWB1", "IN_TRANSIT");
        CourierShipment delivered = shipment("AWB2", "DELIVERED");
        when(shipmentRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId))
                .thenReturn(java.util.List.of(inFlight, delivered));
        when(courierClient.isConfigured(orgId, "SHIPROCKET")).thenReturn(true);
        when(courierClient.trackShipment(orgId, "SHIPROCKET", "AWB1"))
                .thenReturn(Map.of("current_status", "Out For Delivery"));
        when(shipmentRepository.findFirstByOrgIdAndCourierPartnerAndAwbNumberAndIsDeletedFalse(
                orgId, "SHIPROCKET", "AWB1")).thenReturn(Optional.of(inFlight));

        int updated = service.syncOrg();

        assertThat(updated).isEqualTo(1);
        verify(courierClient).trackShipment(orgId, "SHIPROCKET", "AWB1");   // in-flight polled
        verify(courierClient, never()).trackShipment(orgId, "SHIPROCKET", "AWB2"); // terminal skipped
    }
}
