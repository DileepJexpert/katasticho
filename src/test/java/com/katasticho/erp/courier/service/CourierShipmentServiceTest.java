package com.katasticho.erp.courier.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.courier.dto.CourierShipmentDtos.*;
import com.katasticho.erp.courier.entity.CourierShipment;
import com.katasticho.erp.courier.entity.CourierShipmentEvent;
import com.katasticho.erp.courier.repository.CourierShipmentEventRepository;
import com.katasticho.erp.courier.repository.CourierShipmentRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class CourierShipmentServiceTest {

    @Mock private CourierShipmentRepository shipmentRepository;
    @Mock private CourierShipmentEventRepository eventRepository;
    private CourierShipmentService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID contactId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new CourierShipmentService(shipmentRepository, eventRepository);
        TenantContext.setCurrentOrgId(orgId);
        when(shipmentRepository.save(any(CourierShipment.class))).thenAnswer(inv -> {
            CourierShipment s = inv.getArgument(0);
            if (s.getId() == null) s.setId(UUID.randomUUID());
            return s;
        });
        when(eventRepository.findByOrgIdAndCourierShipmentIdOrderByEventAtDesc(any(), any()))
                .thenReturn(List.of());
    }

    @AfterEach
    void tearDown() { TenantContext.clear(); }

    private CreateCourierShipmentRequest req(String awb, boolean cod, BigDecimal codAmount) {
        return new CreateCourierShipmentRequest(
                null, UUID.randomUUID(), contactId, "DELHIVERY", "Surface",
                awb, cod, codAmount, new BigDecimal("80"), new BigDecimal("20"),
                null, new BigDecimal("0.5"), null, null, null, null);
    }

    @Test
    void create_withAwb_isBookedImmediately() {
        CourierShipmentResponse r = service.create(req("AWB123", false, null));

        assertThat(r.status()).isEqualTo("BOOKED");
        assertThat(r.awbNumber()).isEqualTo("AWB123");
        assertThat(r.courierShipmentNumber()).startsWith("CRS-");
    }

    @Test
    void create_withoutAwb_staysDraft() {
        CourierShipmentResponse r = service.create(req(null, false, null));
        assertThat(r.status()).isEqualTo("DRAFT");
        assertThat(r.awbNumber()).isNull();
    }

    @Test
    void create_codWithoutAmount_throws() {
        assertThatThrownBy(() -> service.create(req("AWB1", true, null)))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode())
                .isEqualTo("COURIER_COD_AMOUNT_REQUIRED");
    }

    @Test
    void unknownPartner_throws() {
        assertThatThrownBy(() -> service.create(new CreateCourierShipmentRequest(
                null, null, contactId, "FEDEX", null, "A", false, null, null, null,
                null, null, null, null, null, null)))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode())
                .isEqualTo("COURIER_BAD_PARTNER");
    }

    @Test
    void markBooked_attachesAwbAndFlipsStatus() {
        CourierShipment draft = CourierShipment.builder()
                .courierPartner("DELHIVERY").status("DRAFT").contactId(contactId).build();
        draft.setId(UUID.randomUUID());
        draft.setOrgId(orgId);
        when(shipmentRepository.findByIdAndOrgIdAndIsDeletedFalse(draft.getId(), orgId))
                .thenReturn(Optional.of(draft));

        CourierShipmentResponse r = service.markBooked(draft.getId(), "AWB-NEW");
        assertThat(r.status()).isEqualTo("BOOKED");
        assertThat(r.awbNumber()).isEqualTo("AWB-NEW");
    }

    @Test
    void recordEvent_DELIVERED_stampsTimestampAndUpdatesStatus() {
        CourierShipment in = CourierShipment.builder()
                .courierPartner("DELHIVERY").status("IN_TRANSIT").contactId(contactId).build();
        in.setId(UUID.randomUUID());
        in.setOrgId(orgId);
        when(shipmentRepository.findByIdAndOrgIdAndIsDeletedFalse(in.getId(), orgId))
                .thenReturn(Optional.of(in));

        service.recordEvent(in.getId(), new RecordEventRequest(
                "DELIVERED", null, "Hub-DEL", null, "WEBHOOK"));

        ArgumentCaptor<CourierShipmentEvent> evCap = ArgumentCaptor.forClass(CourierShipmentEvent.class);
        verify(eventRepository).save(evCap.capture());
        assertThat(evCap.getValue().getEventStatus()).isEqualTo("DELIVERED");
        assertThat(evCap.getValue().getSource()).isEqualTo("WEBHOOK");

        assertThat(in.getStatus()).isEqualTo("DELIVERED");
        assertThat(in.getDeliveredAt()).isNotNull();
    }

    @Test
    void recordEvent_EXCEPTION_preservesStatus() {
        CourierShipment in = CourierShipment.builder()
                .courierPartner("DELHIVERY").status("IN_TRANSIT").contactId(contactId).build();
        in.setId(UUID.randomUUID());
        in.setOrgId(orgId);
        when(shipmentRepository.findByIdAndOrgIdAndIsDeletedFalse(in.getId(), orgId))
                .thenReturn(Optional.of(in));

        service.recordEvent(in.getId(), new RecordEventRequest(
                "EXCEPTION", null, "Address unclear", null, "POLL"));

        assertThat(in.getStatus()).isEqualTo("IN_TRANSIT"); // unchanged
        verify(eventRepository).save(any()); // event still recorded
    }

    @Test
    void recordEvent_RTO_DELIVERED_stampsBothRtoTimestamps() {
        CourierShipment in = CourierShipment.builder()
                .courierPartner("DELHIVERY").status("OUT_FOR_DELIVERY").contactId(contactId).build();
        in.setId(UUID.randomUUID());
        in.setOrgId(orgId);
        when(shipmentRepository.findByIdAndOrgIdAndIsDeletedFalse(in.getId(), orgId))
                .thenReturn(Optional.of(in));

        service.recordEvent(in.getId(), new RecordEventRequest("RTO_DELIVERED", null, null, null, "WEBHOOK"));

        assertThat(in.getStatus()).isEqualTo("RTO_DELIVERED");
        assertThat(in.getRtoInitiatedAt()).isNotNull();   // back-filled when RTO_INITIATED was missed
        assertThat(in.getRtoDeliveredAt()).isNotNull();
    }

    @Test
    void cancel_fromInTransit_throws() {
        CourierShipment in = CourierShipment.builder()
                .courierPartner("DELHIVERY").status("IN_TRANSIT").contactId(contactId).build();
        in.setId(UUID.randomUUID());
        in.setOrgId(orgId);
        when(shipmentRepository.findByIdAndOrgIdAndIsDeletedFalse(in.getId(), orgId))
                .thenReturn(Optional.of(in));

        assertThatThrownBy(() -> service.cancel(in.getId(), "tried"))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode())
                .isEqualTo("COURIER_NOT_CANCELLABLE");
    }
}
