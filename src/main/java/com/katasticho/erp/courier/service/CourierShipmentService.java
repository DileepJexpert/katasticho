package com.katasticho.erp.courier.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.courier.dto.CourierShipmentDtos.*;
import com.katasticho.erp.courier.entity.CourierShipment;
import com.katasticho.erp.courier.entity.CourierShipmentEvent;
import com.katasticho.erp.courier.repository.CourierShipmentEventRepository;
import com.katasticho.erp.courier.repository.CourierShipmentRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;

/**
 * Courier shipment lifecycle and event ingestion.
 *
 * <p><b>Lifecycle:</b> {@code DRAFT → BOOKED → PICKED_UP → IN_TRANSIT
 * → OUT_FOR_DELIVERY → DELIVERED}. RTO branches: any in-transit status can flip
 * to {@code RTO_INITIATED → RTO_DELIVERED}. {@code CANCELLED} is allowed from
 * {@code DRAFT} or {@code BOOKED}.
 *
 * <p><b>Status feed:</b> each call to {@link #recordEvent} appends a row to
 * {@code courier_shipment_event} (append-only, like stock movements) and reflects
 * the new status on the shipment. RTO timestamps are stamped here so a remittance
 * settler can later tell "is this AWB still expected to be paid?".
 *
 * <p><b>Returns/RTO accounting:</b> the moment an RTO is delivered back to the
 * seller, the shipment is flagged and the inventory + AR consequences are
 * handled through existing flows — the owner picks credit-note vs. cancel-invoice
 * via the regular AR screens. We don't auto-issue accounting here; the agent
 * surfaces the RTO and a human approves the reversal (same rule as everywhere
 * else in this codebase).
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class CourierShipmentService {

    private static final Set<String> CANCELLABLE = Set.of("DRAFT", "BOOKED");
    private static final Set<String> RTO_TRIGGERS = Set.of("RTO_INITIATED", "RTO_DELIVERED");
    private static final Set<String> EVENT_STATUSES = Set.of(
            "PICKED_UP", "IN_TRANSIT", "OUT_FOR_DELIVERY", "DELIVERED",
            "RTO_INITIATED", "RTO_DELIVERED", "EXCEPTION");

    private final CourierShipmentRepository shipmentRepository;
    private final CourierShipmentEventRepository eventRepository;

    // ── Create / book / cancel ───────────────────────────────────────────

    @Transactional
    public CourierShipmentResponse create(CreateCourierShipmentRequest req) {
        UUID orgId = requireOrgId();
        validatePartner(req.courierPartner());

        if (req.cod() && (req.codAmount() == null || req.codAmount().signum() <= 0)) {
            throw new BusinessException(
                    "COD shipments need a positive cod_amount",
                    "COURIER_COD_AMOUNT_REQUIRED", HttpStatus.BAD_REQUEST);
        }

        CourierShipment shipment = CourierShipment.builder()
                .courierShipmentNumber(nextShipmentNumber(orgId))
                .deliveryChallanId(req.deliveryChallanId())
                .invoiceId(req.invoiceId())
                .contactId(req.contactId())
                .courierPartner(req.courierPartner())
                .courierService(req.courierService())
                .awbNumber(trimToNull(req.awbNumber()))
                .status(trimToNull(req.awbNumber()) == null ? "DRAFT" : "BOOKED")
                .cod(req.cod())
                .codAmount(nz(req.codAmount()))
                .freightAmount(nz(req.freightAmount()))
                .codFee(nz(req.codFee()))
                .transporterContactId(req.transporterContactId())
                .weightKg(req.weightKg())
                .declaredValue(req.declaredValue())
                .pickupAddress(req.pickupAddress())
                .deliveryAddress(req.deliveryAddress())
                .notes(req.notes())
                .build();
        shipment.setOrgId(orgId);
        if (shipment.getAwbNumber() != null) shipment.setBookedAt(Instant.now());

        shipment = shipmentRepository.save(shipment);
        log.info("Courier shipment {} created (partner={}, status={}) for org {}",
                shipment.getCourierShipmentNumber(), shipment.getCourierPartner(), shipment.getStatus(), orgId);
        return toResponse(shipment, List.of());
    }

    /** Attach an AWB after the partner has booked the parcel (DRAFT → BOOKED). */
    @Transactional
    public CourierShipmentResponse markBooked(UUID id, String awbNumber) {
        CourierShipment s = require(id);
        if (!"DRAFT".equals(s.getStatus())) {
            throw new BusinessException(
                    "Only DRAFT shipments can be booked (current: " + s.getStatus() + ")",
                    "COURIER_BAD_STATE", HttpStatus.CONFLICT);
        }
        String awb = trimToNull(awbNumber);
        if (awb == null) {
            throw new BusinessException("AWB number is required to book",
                    "COURIER_AWB_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        s.setAwbNumber(awb);
        s.setStatus("BOOKED");
        s.setBookedAt(Instant.now());
        shipmentRepository.save(s);
        return toResponse(s);
    }

    @Transactional
    public CourierShipmentResponse cancel(UUID id, String reason) {
        CourierShipment s = require(id);
        if (!CANCELLABLE.contains(s.getStatus())) {
            throw new BusinessException(
                    "Cannot cancel a shipment in status " + s.getStatus(),
                    "COURIER_NOT_CANCELLABLE", HttpStatus.CONFLICT);
        }
        s.setStatus("CANCELLED");
        if (reason != null && !reason.isBlank()) {
            s.setNotes((s.getNotes() == null ? "" : s.getNotes() + "\n") + "Cancelled: " + reason);
        }
        shipmentRepository.save(s);
        return toResponse(s);
    }

    // ── Event ingestion (webhook / poll / manual) ────────────────────────

    /**
     * Append a status event and reflect the new status on the shipment. The
     * status feed is append-only — corrections come as new events (same rule
     * as stock movements). Terminal statuses stamp the timestamps that downstream
     * flows (COD reconciliation, RTO accounting) key off.
     */
    @Transactional
    public CourierShipmentResponse recordEvent(UUID id, RecordEventRequest req) {
        CourierShipment s = require(id);
        String eventStatus = req.eventStatus() == null ? "" : req.eventStatus().trim().toUpperCase();
        if (!EVENT_STATUSES.contains(eventStatus)) {
            throw new BusinessException(
                    "Unknown courier event: " + eventStatus + ". Known: " + EVENT_STATUSES,
                    "COURIER_BAD_EVENT", HttpStatus.BAD_REQUEST);
        }
        if ("CANCELLED".equals(s.getStatus())) {
            throw new BusinessException(
                    "Cannot record events on a CANCELLED shipment",
                    "COURIER_BAD_STATE", HttpStatus.CONFLICT);
        }

        Instant when = req.eventAt() != null ? req.eventAt() : Instant.now();
        eventRepository.save(CourierShipmentEvent.builder()
                .orgId(s.getOrgId())
                .courierShipmentId(s.getId())
                .eventStatus(eventStatus)
                .eventAt(when)
                .location(req.location())
                .rawPayload(req.rawPayload())
                .source(req.source() == null || req.source().isBlank() ? "MANUAL" : req.source().toUpperCase())
                .build());

        // EXCEPTION is informational — keeps the prior status.
        if (!"EXCEPTION".equals(eventStatus)) {
            s.setStatus(eventStatus);
            if ("DELIVERED".equals(eventStatus)) s.setDeliveredAt(when);
            if ("RTO_INITIATED".equals(eventStatus) && s.getRtoInitiatedAt() == null) {
                s.setRtoInitiatedAt(when);
            }
            if ("RTO_DELIVERED".equals(eventStatus)) {
                if (s.getRtoInitiatedAt() == null) s.setRtoInitiatedAt(when);
                s.setRtoDeliveredAt(when);
            }
            shipmentRepository.save(s);
        }
        log.info("Courier event {} recorded for shipment {} (org {})",
                eventStatus, s.getCourierShipmentNumber(), s.getOrgId());
        return toResponse(s);
    }

    // ── Queries ──────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public CourierShipmentResponse get(UUID id) {
        return toResponse(require(id));
    }

    @Transactional(readOnly = true)
    public List<CourierShipmentResponse> list(String status) {
        UUID orgId = requireOrgId();
        List<CourierShipment> rows = (status == null || status.isBlank())
                ? shipmentRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId)
                : shipmentRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(
                        orgId, status.toUpperCase());
        List<CourierShipmentResponse> out = new ArrayList<>();
        for (CourierShipment s : rows) out.add(toResponse(s, List.of()));   // skip events in lists
        return out;
    }

    /** Returned-to-seller shipments awaiting credit-note / stock-restock action. */
    @Transactional(readOnly = true)
    public List<CourierShipmentResponse> pendingRtoReversal() {
        UUID orgId = requireOrgId();
        return shipmentRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(
                        orgId, "RTO_DELIVERED").stream()
                .map(s -> toResponse(s, List.of()))
                .toList();
    }

    // ── Internals ────────────────────────────────────────────────────────

    private CourierShipment require(UUID id) {
        UUID orgId = requireOrgId();
        return shipmentRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> new BusinessException(
                        "Courier shipment not found", "COURIER_NOT_FOUND", HttpStatus.NOT_FOUND));
    }

    private CourierShipmentResponse toResponse(CourierShipment s) {
        return toResponse(s, eventRepository.findByOrgIdAndCourierShipmentIdOrderByEventAtDesc(
                s.getOrgId(), s.getId()).stream()
                .map(e -> new EventResponse(e.getId(), e.getEventStatus(), e.getEventAt(),
                        e.getLocation(), e.getSource()))
                .toList());
    }

    private CourierShipmentResponse toResponse(CourierShipment s, List<EventResponse> events) {
        return new CourierShipmentResponse(
                s.getId(), s.getCourierShipmentNumber(), s.getDeliveryChallanId(),
                s.getInvoiceId(), s.getContactId(), s.getCourierPartner(), s.getCourierService(),
                s.getAwbNumber(), s.getStatus(), s.isCod(), s.getCodAmount(),
                s.getCodRemittanceLineId(), s.getFreightAmount(), s.getCodFee(),
                s.getTransporterContactId(), s.getWeightKg(), s.getDeclaredValue(),
                s.getBookedAt(), s.getDeliveredAt(), s.getRtoInitiatedAt(),
                s.getRtoDeliveredAt(), s.getNotes(), events);
    }

    private String nextShipmentNumber(UUID orgId) {
        long count = shipmentRepository.countByOrgIdAndIsDeletedFalse(orgId);
        return String.format("CRS-%05d", count + 1);
    }

    private void validatePartner(String partner) {
        if (!CourierClient.PARTNERS.contains(partner)) {
            throw new BusinessException(
                    "Unknown courier partner: " + partner + ". Known: " + CourierClient.PARTNERS,
                    "COURIER_BAD_PARTNER", HttpStatus.BAD_REQUEST);
        }
    }

    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }

    private static String trimToNull(String s) {
        if (s == null) return null;
        String t = s.trim();
        return t.isEmpty() ? null : t;
    }

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
