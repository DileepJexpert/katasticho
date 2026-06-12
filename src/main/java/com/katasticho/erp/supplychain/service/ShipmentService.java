package com.katasticho.erp.supplychain.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.supplychain.entity.Shipment;
import com.katasticho.erp.supplychain.entity.ShipmentLine;
import com.katasticho.erp.supplychain.repository.ShipmentRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class ShipmentService {

    private final ShipmentRepository shipmentRepo;

    // ── Create ───────────────────────────────────────────────────────────────

    @Transactional
    public Shipment createShipment(String shipmentType,
                                   UUID originWarehouseId,
                                   UUID destinationWarehouseId,
                                   String carrier,
                                   String vehicleNumber,
                                   Instant estimatedDeparture,
                                   Instant estimatedArrival,
                                   BigDecimal freightCost,
                                   String notes,
                                   List<Map<String, Object>> lineData) {
        UUID orgId = TenantContext.getCurrentOrgId();

        String shipmentNumber = generateShipmentNumber(orgId);

        Shipment shipment = Shipment.builder()
                .shipmentNumber(shipmentNumber)
                .shipmentType(shipmentType != null ? shipmentType : "OUTBOUND")
                .status("DRAFT")
                .originWarehouseId(originWarehouseId)
                .destinationWarehouseId(destinationWarehouseId)
                .carrier(carrier)
                .vehicleNumber(vehicleNumber)
                .estimatedDeparture(estimatedDeparture)
                .estimatedArrival(estimatedArrival)
                .freightCost(freightCost != null ? freightCost : BigDecimal.ZERO)
                .notes(notes)
                .lines(new ArrayList<>())
                .build();

        if (lineData != null) {
            for (Map<String, Object> ld : lineData) {
                UUID itemId = UUID.fromString((String) ld.get("itemId"));
                BigDecimal qty = new BigDecimal(ld.get("quantity").toString());
                BigDecimal weight = ld.containsKey("weight") && ld.get("weight") != null
                        ? new BigDecimal(ld.get("weight").toString()) : null;
                int packages = ld.containsKey("packages") && ld.get("packages") != null
                        ? Integer.parseInt(ld.get("packages").toString()) : 1;
                String refType = (String) ld.get("referenceType");
                UUID refId = ld.containsKey("referenceId") && ld.get("referenceId") != null
                        ? UUID.fromString((String) ld.get("referenceId")) : null;

                ShipmentLine line = ShipmentLine.builder()
                        .shipment(shipment)
                        .itemId(itemId)
                        .quantity(qty)
                        .weight(weight)
                        .packages(packages)
                        .referenceType(refType)
                        .referenceId(refId)
                        .notes((String) ld.get("notes"))
                        .build();
                shipment.getLines().add(line);
            }
        }

        shipment = shipmentRepo.save(shipment);
        log.info("Created shipment {} ({}) for org {}", shipmentNumber, shipmentType, orgId);
        return shipment;
    }

    // ── Dispatch ─────────────────────────────────────────────────────────────

    @Transactional
    public Shipment dispatchShipment(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Shipment shipment = getShipmentOrThrow(id, orgId);

        if (!"DRAFT".equals(shipment.getStatus()) && !"READY".equals(shipment.getStatus())) {
            throw new BusinessException(
                    "Only DRAFT or READY shipments can be dispatched, current: " + shipment.getStatus(),
                    "SHIPMENT_INVALID_STATE", HttpStatus.BAD_REQUEST);
        }

        shipment.setStatus("IN_TRANSIT");
        shipment.setActualDeparture(Instant.now());
        shipment = shipmentRepo.save(shipment);

        log.info("Dispatched shipment {} for org {}", shipment.getShipmentNumber(), orgId);
        return shipment;
    }

    // ── Deliver ──────────────────────────────────────────────────────────────

    @Transactional
    public Shipment deliverShipment(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Shipment shipment = getShipmentOrThrow(id, orgId);

        if (!"IN_TRANSIT".equals(shipment.getStatus())) {
            throw new BusinessException(
                    "Only IN_TRANSIT shipments can be marked as delivered, current: " + shipment.getStatus(),
                    "SHIPMENT_INVALID_STATE", HttpStatus.BAD_REQUEST);
        }

        shipment.setStatus("DELIVERED");
        shipment.setActualArrival(Instant.now());
        shipment = shipmentRepo.save(shipment);

        log.info("Delivered shipment {} for org {}", shipment.getShipmentNumber(), orgId);
        return shipment;
    }

    // ── Cancel ───────────────────────────────────────────────────────────────

    @Transactional
    public Shipment cancelShipment(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Shipment shipment = getShipmentOrThrow(id, orgId);

        if ("DELIVERED".equals(shipment.getStatus()) || "CANCELLED".equals(shipment.getStatus())) {
            throw new BusinessException(
                    "Cannot cancel a DELIVERED or already CANCELLED shipment",
                    "SHIPMENT_CANNOT_CANCEL", HttpStatus.BAD_REQUEST);
        }

        shipment.setStatus("CANCELLED");
        shipment = shipmentRepo.save(shipment);

        log.info("Cancelled shipment {} for org {}", shipment.getShipmentNumber(), orgId);
        return shipment;
    }

    // ── Queries ───────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public Shipment getShipment(UUID id) {
        return getShipmentOrThrow(id, TenantContext.getCurrentOrgId());
    }

    @Transactional(readOnly = true)
    public List<Shipment> listShipments(String status, String type) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (status != null && type != null) {
            return shipmentRepo.findByOrgIdAndStatusAndShipmentTypeAndIsDeletedFalseOrderByCreatedAtDesc(
                    orgId, status, type);
        } else if (status != null) {
            return shipmentRepo.findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(orgId, status);
        } else if (type != null) {
            return shipmentRepo.findByOrgIdAndShipmentTypeAndIsDeletedFalseOrderByCreatedAtDesc(orgId, type);
        }
        return shipmentRepo.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private Shipment getShipmentOrThrow(UUID id, UUID orgId) {
        return shipmentRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Shipment", id));
    }

    private String generateShipmentNumber(UUID orgId) {
        long count = shipmentRepo.countByOrgIdAndIsDeletedFalse(orgId);
        return String.format("SHP-%05d", count + 1);
    }
}
