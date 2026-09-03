package com.katasticho.erp.inventory.transit.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.transit.dto.DispatchCreateRequest;
import com.katasticho.erp.inventory.transit.dto.TransferOrderDispatchResponse;
import com.katasticho.erp.inventory.transit.dto.TransitPingRequest;
import com.katasticho.erp.inventory.transit.entity.TransferOrderDispatch;
import com.katasticho.erp.inventory.transit.entity.TransferOrderTransitEvent;
import com.katasticho.erp.inventory.transit.repository.TransferOrderDispatchRepository;
import com.katasticho.erp.inventory.transit.repository.TransferOrderTransitEventRepository;
import com.katasticho.erp.inventory.entity.TransferOrder;
import com.katasticho.erp.inventory.repository.TransferOrderRepository;
import com.katasticho.erp.inventory.service.TransferOrderService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.http.HttpStatus;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class StockTransferTransitService {

    private final TransferOrderDispatchRepository dispatchRepository;
    private final TransferOrderTransitEventRepository eventRepository;
    private final TransferOrderRepository transferOrderRepository;
    private final TransferOrderService transferOrderService;

    @Transactional(readOnly = true)
    public List<TransferOrderDispatchResponse> listDispatches(String status) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<TransferOrderDispatch> list;
        if (status != null && !status.isBlank() && !"ALL".equalsIgnoreCase(status)) {
            list = dispatchRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByDispatchedAtDesc(orgId, status.toUpperCase());
        } else {
            list = dispatchRepository.findByOrgIdAndIsDeletedFalseOrderByDispatchedAtDesc(orgId);
        }
        return list.stream().map(TransferOrderDispatchResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public TransferOrderDispatchResponse getDispatch(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        TransferOrderDispatch dispatch = dispatchRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, id)
                .orElseThrow(() -> BusinessException.notFound("TransferOrderDispatch", id));
        return TransferOrderDispatchResponse.from(dispatch);
    }

    @Transactional
    public TransferOrderDispatchResponse createDispatch(DispatchCreateRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        TransferOrder transferOrder = transferOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(request.getTransferOrderId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Transfer Order", request.getTransferOrderId()));
        if (!"IN_TRANSIT".equals(transferOrder.getStatus())) {
            throw new BusinessException("A transit dispatch can be created only after the transfer order is shipped",
                    "TRANSIT_TRANSFER_NOT_SHIPPED", HttpStatus.CONFLICT);
        }
        if (dispatchRepository.findByOrgIdAndTransferOrderIdAndIsDeletedFalse(orgId, request.getTransferOrderId()).isPresent()) {
            throw new BusinessException("A transit dispatch already exists for this transfer order",
                    "TRANSIT_DISPATCH_EXISTS", HttpStatus.CONFLICT);
        }

        TransferOrderDispatch dispatch = TransferOrderDispatch.builder()
                .transferOrderId(request.getTransferOrderId())
                .vehicleNumber(request.getVehicleNumber().toUpperCase().trim())
                .driverName(request.getDriverName().trim())
                .driverPhone(request.getDriverPhone())
                .dispatchedAt(Instant.now())
                .expectedDeliveryAt(request.getExpectedDeliveryAt())
                .status("DISPATCHED")
                .events(new ArrayList<>())
                .build();
        dispatch.setOrgId(orgId);

        TransferOrderTransitEvent initialEvent = TransferOrderTransitEvent.builder()
                .dispatch(dispatch)
                .eventType("DISPATCHED")
                .locationName("Source Warehouse Dock")
                .eventNotes("Vehicle dispatched and departed source warehouse")
                .build();
        dispatch.getEvents().add(initialEvent);

        TransferOrderDispatch saved = dispatchRepository.save(dispatch);
        log.info("Created transfer order dispatch [{}] for TO [{}] vehicle [{}]", saved.getId(), request.getTransferOrderId(), dispatch.getVehicleNumber());
        return TransferOrderDispatchResponse.from(saved);
    }

    @Transactional
    public TransferOrderDispatchResponse recordPing(UUID dispatchId, TransitPingRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        TransferOrderDispatch dispatch = dispatchRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, dispatchId)
                .orElseThrow(() -> BusinessException.notFound("TransferOrderDispatch", dispatchId));
        if (!"DISPATCHED".equals(dispatch.getStatus()) && !"IN_TRANSIT".equals(dispatch.getStatus())) {
            throw new BusinessException("Location updates are allowed only while the shipment is in transit",
                    "TRANSIT_DISPATCH_NOT_ACTIVE", HttpStatus.CONFLICT);
        }

        dispatch.setLatitude(request.getLatitude());
        dispatch.setLongitude(request.getLongitude());
        dispatch.setLastLocationName(request.getLocationName());
        dispatch.setLastPingAt(Instant.now());
        if ("DISPATCHED".equals(dispatch.getStatus())) {
            dispatch.setStatus("IN_TRANSIT");
        }

        String eventType = request.getEventType() != null ? request.getEventType().toUpperCase() : "CHECKPOINT";
        if (!"CHECKPOINT".equals(eventType) && !"DELAY_ALERT".equals(eventType)) {
            throw new BusinessException("Transit telemetry event type must be CHECKPOINT or DELAY_ALERT",
                    "TRANSIT_INVALID_EVENT_TYPE", HttpStatus.BAD_REQUEST);
        }

        TransferOrderTransitEvent event = TransferOrderTransitEvent.builder()
                .dispatch(dispatch)
                .eventType(eventType)
                .latitude(request.getLatitude())
                .longitude(request.getLongitude())
                .locationName(request.getLocationName())
                .eventNotes(request.getEventNotes())
                .build();
        dispatch.getEvents().add(event);

        TransferOrderDispatch saved = dispatchRepository.save(dispatch);
        log.info("Recorded GPS telemetry ping for dispatch [{}] at [{}]", dispatchId, request.getLocationName());
        return TransferOrderDispatchResponse.from(saved);
    }

    @Transactional
    public TransferOrderDispatchResponse markDelivered(UUID dispatchId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        TransferOrderDispatch dispatch = dispatchRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, dispatchId)
                .orElseThrow(() -> BusinessException.notFound("TransferOrderDispatch", dispatchId));
        if (!"DISPATCHED".equals(dispatch.getStatus()) && !"IN_TRANSIT".equals(dispatch.getStatus())) {
            throw new BusinessException("Only active transit dispatches can be marked delivered",
                    "TRANSIT_DISPATCH_NOT_ACTIVE", HttpStatus.CONFLICT);
        }

        dispatch.setStatus("DELIVERED");
        dispatch.setDeliveredAt(Instant.now());

        TransferOrderTransitEvent event = TransferOrderTransitEvent.builder()
                .dispatch(dispatch)
                .eventType("DELIVERED")
                .locationName(dispatch.getLastLocationName() != null ? dispatch.getLastLocationName() : "Destination Warehouse")
                .eventNotes("Shipment arrived at destination and awaits warehouse receipt")
                .build();
        dispatch.getEvents().add(event);

        TransferOrderDispatch saved = dispatchRepository.save(dispatch);
        log.info("Marked transfer order dispatch [{}] as DELIVERED", dispatchId);
        return TransferOrderDispatchResponse.from(saved);
    }

    @Transactional
    public TransferOrderDispatchResponse receiveAtDestination(UUID dispatchId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        TransferOrderDispatch dispatch = dispatchRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, dispatchId)
                .orElseThrow(() -> BusinessException.notFound("TransferOrderDispatch", dispatchId));
        if (!"DELIVERED".equals(dispatch.getStatus())) {
            throw new BusinessException("Only delivered shipments can be received into destination stock",
                    "TRANSIT_DISPATCH_NOT_DELIVERED", HttpStatus.CONFLICT);
        }

        transferOrderService.receive(dispatch.getTransferOrderId());
        dispatch.setStatus("RECEIVED");
        dispatch.getEvents().add(TransferOrderTransitEvent.builder()
                .dispatch(dispatch)
                .eventType("RECEIVED")
                .locationName(dispatch.getLastLocationName() != null ? dispatch.getLastLocationName() : "Destination Warehouse")
                .eventNotes("Destination warehouse receipt posted to inventory")
                .build());

        return TransferOrderDispatchResponse.from(dispatchRepository.save(dispatch));
    }
}
