package com.katasticho.erp.courier.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.courier.dto.CodRemittanceDtos.*;
import com.katasticho.erp.courier.dto.CourierShipmentDtos.CourierShipmentResponse;
import com.katasticho.erp.courier.dto.CourierShipmentDtos.RecordEventRequest;
import com.katasticho.erp.courier.entity.CourierShipment;
import com.katasticho.erp.courier.repository.CourierShipmentRepository;
import com.katasticho.erp.courier.service.TrackingPayloadParser.TrackingUpdate;
import com.katasticho.erp.organisation.OrgSetting;
import com.katasticho.erp.organisation.OrgSettingsRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;

/**
 * Makes courier tracking live: pulls status from the aggregator (poll), accepts
 * pushed status (webhook), and pulls COD remittance files — all funneling through
 * the same {@link CourierShipmentService} / {@link CodReconciliationService}
 * already built, so the lifecycle and accounting rules are unchanged.
 *
 * <p>Status from the aggregator is normalised by {@link CourierStatusMapper}, and
 * {@link #applyTracking} de-dupes: it skips a poll that reports the same status,
 * and never moves a parcel past a terminal state (DELIVERED / RTO_DELIVERED /
 * CANCELLED). All callers run inside a tenant context.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class CourierTrackingService {

    private static final Set<String> TERMINAL = Set.of("DELIVERED", "RTO_DELIVERED", "CANCELLED");
    private static final Set<String> NON_TERMINAL_POLLABLE = Set.of(
            "BOOKED", "PICKED_UP", "IN_TRANSIT", "OUT_FOR_DELIVERY", "RTO_INITIATED");

    private final CourierShipmentRepository shipmentRepository;
    private final CourierShipmentService shipmentService;
    private final CourierClient courierClient;
    private final CodReconciliationService codReconciliationService;
    private final OrgSettingsRepository orgSettingsRepository;

    // ── Apply one status update (the shared core) ────────────────────────

    /** @return true if a new event was recorded; false if skipped (no match / no-op / terminal). */
    @Transactional
    public boolean applyTracking(String partner, String awb, String statusRaw,
                                 Instant eventAt, String location, String rawPayload, String source) {
        UUID orgId = requireOrgId();
        if (awb == null || awb.isBlank()) return false;
        String canonical = CourierStatusMapper.toCanonical(statusRaw);
        if (canonical == null) return false;

        CourierShipment shipment = shipmentRepository
                .findFirstByOrgIdAndCourierPartnerAndAwbNumberAndIsDeletedFalse(orgId, partner, awb.trim())
                .or(() -> shipmentRepository.findFirstByOrgIdAndAwbNumberAndIsDeletedFalse(orgId, awb.trim()))
                .orElse(null);
        if (shipment == null) {
            log.debug("Courier tracking: no shipment for AWB {} (org {})", awb, orgId);
            return false;
        }
        if (TERMINAL.contains(shipment.getStatus()) || canonical.equals(shipment.getStatus())) {
            return false; // already terminal, or no change since last poll
        }
        shipmentService.recordEvent(shipment.getId(), new RecordEventRequest(
                canonical, eventAt, location, rawPayload, source));
        return true;
    }

    // ── Poll (manual + bulk) ─────────────────────────────────────────────

    /** Poll one shipment's AWB from the aggregator and apply any status advance. */
    @Transactional
    public CourierShipmentResponse syncShipment(UUID shipmentId) {
        UUID orgId = requireOrgId();
        CourierShipment s = shipmentRepository.findByIdAndOrgIdAndIsDeletedFalse(shipmentId, orgId)
                .orElseThrow(() -> new BusinessException(
                        "Courier shipment not found", "COURIER_NOT_FOUND", HttpStatus.NOT_FOUND));
        if (s.getAwbNumber() == null || s.getAwbNumber().isBlank()) {
            throw new BusinessException("Shipment has no AWB to track yet",
                    "COURIER_NO_AWB", HttpStatus.BAD_REQUEST);
        }
        if (!courierClient.isConfigured(orgId, s.getCourierPartner())) {
            throw new BusinessException(
                    s.getCourierPartner() + " is not connected — record events manually or set up the courier",
                    "COURIER_NOT_CONFIGURED", HttpStatus.BAD_REQUEST);
        }
        Map<String, Object> resp = courierClient.trackShipment(orgId, s.getCourierPartner(), s.getAwbNumber());
        TrackingUpdate u = TrackingPayloadParser.parse(resp);
        if (u.usable()) {
            applyTracking(s.getCourierPartner(), s.getAwbNumber(), u.statusRaw(),
                    u.eventAt() != null ? u.eventAt() : Instant.now(), u.location(), null, "POLL");
        }
        return shipmentService.get(shipmentId);
    }

    /** Poll every in-flight shipment for the current org (used by the scheduled job). */
    @Transactional
    public int syncOrg() {
        UUID orgId = requireOrgId();
        int applied = 0;
        for (CourierShipment s : shipmentRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId)) {
            if (s.getAwbNumber() == null || s.getAwbNumber().isBlank()) continue;
            if (!NON_TERMINAL_POLLABLE.contains(s.getStatus())) continue;
            if (!courierClient.isConfigured(orgId, s.getCourierPartner())) continue;
            try {
                Map<String, Object> resp = courierClient.trackShipment(orgId, s.getCourierPartner(), s.getAwbNumber());
                TrackingUpdate u = TrackingPayloadParser.parse(resp);
                if (u.usable() && applyTracking(s.getCourierPartner(), s.getAwbNumber(), u.statusRaw(),
                        u.eventAt() != null ? u.eventAt() : Instant.now(), u.location(), null, "POLL")) {
                    applied++;
                }
            } catch (Exception e) {
                log.debug("Poll failed for AWB {} (org {}): {}", s.getAwbNumber(), orgId, e.getMessage());
            }
        }
        return applied;
    }

    // ── Webhook ──────────────────────────────────────────────────────────

    /** Resolve the org that owns a webhook token for a partner (public-endpoint routing). */
    public Optional<UUID> resolveOrgByWebhookToken(String partner, String token) {
        if (token == null || token.isBlank()) return Optional.empty();
        String key = "courier." + partner.toLowerCase().replace('-', '_') + CourierClient.WEBHOOK_TOKEN_SUFFIX;
        return orgSettingsRepository.findFirstByKeyAndValue(key, token.trim()).map(OrgSetting::getOrgId);
    }

    /** Apply a pushed status update. TenantContext must already be set to the resolved org. */
    @Transactional
    public boolean ingestWebhook(String partner, Map<String, Object> payload) {
        TrackingUpdate u = TrackingPayloadParser.parse(payload);
        if (!u.usable()) return false;
        return applyTracking(partner, u.awb(), u.statusRaw(),
                u.eventAt() != null ? u.eventAt() : Instant.now(), u.location(),
                truncate(payload.toString()), "WEBHOOK");
    }

    // ── COD remittance pull ──────────────────────────────────────────────

    /** Pull a COD payout from the aggregator into a DRAFT remittance the owner reconciles. */
    @Transactional
    public CodRemittanceResponse pullCodRemittance(String partner, String fromDate, String toDate) {
        UUID orgId = requireOrgId();
        if (!courierClient.isConfigured(orgId, partner)) {
            throw new BusinessException(
                    partner + " is not connected — enter the remittance manually instead",
                    "COURIER_NOT_CONFIGURED", HttpStatus.BAD_REQUEST);
        }
        Map<String, Object> resp = courierClient.fetchCodRemittance(orgId, partner, fromDate, toDate);
        CreateCodRemittanceRequest req = parseRemittance(partner, resp, toDate);
        if (req.lines().isEmpty()) {
            throw new BusinessException(
                    "No COD lines found in the courier's response — enter it manually",
                    "COURIER_COD_PARSE_FAILED", HttpStatus.BAD_GATEWAY);
        }
        return codReconciliationService.create(req);
    }

    @SuppressWarnings("unchecked")
    private CreateCodRemittanceRequest parseRemittance(String partner, Map<String, Object> json, String toDate) {
        Object data = json == null ? null : json.getOrDefault("data", json);
        Map<String, Object> root = data instanceof Map ? (Map<String, Object>) data : json;
        List<CodLineInput> lines = new ArrayList<>();
        if (root != null) {
            Object listObj = firstList(root, "remittances", "cod_remittance", "results",
                    "line_items", "awbs", "data");
            if (listObj instanceof List<?> list) {
                for (Object o : list) {
                    if (!(o instanceof Map<?, ?> m)) continue;
                    Map<String, Object> line = (Map<String, Object>) m;
                    String awb = strKey(line, "awb", "awb_code", "waybill");
                    BigDecimal cod = numKey(line, "cod_amount", "amount", "cod", "collectable_amount");
                    BigDecimal fee = numKey(line, "fee", "charges", "deduction", "cod_charges");
                    if (awb != null && cod != null) {
                        lines.add(new CodLineInput(awb, cod, fee == null ? BigDecimal.ZERO : fee));
                    }
                }
            }
        }
        String utr = root == null ? null : strKey(root, "utr", "reference", "transaction_id", "payment_ref");
        BigDecimal net = root == null ? null : numKey(root, "net_amount", "amount_credited", "total_amount", "net");
        LocalDate date = parseDateOrToday(toDate);
        return new CreateCodRemittanceRequest(partner, date, null, utr,
                net == null ? BigDecimal.ZERO : net, "Pulled from " + partner, lines);
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private static Object firstList(Map<String, Object> m, String... keys) {
        for (String k : keys) {
            if (m.get(k) instanceof List<?> l) return l;
        }
        return null;
    }

    private static String strKey(Map<String, Object> m, String... keys) {
        for (String k : keys) {
            Object v = m.get(k);
            if (v != null && !v.toString().isBlank()) return v.toString().trim();
        }
        return null;
    }

    private static BigDecimal numKey(Map<String, Object> m, String... keys) {
        for (String k : keys) {
            Object v = m.get(k);
            if (v == null) continue;
            try {
                return new BigDecimal(v.toString().trim());
            } catch (NumberFormatException ignored) { /* next */ }
        }
        return null;
    }

    private static LocalDate parseDateOrToday(String s) {
        if (s != null && !s.isBlank()) {
            try {
                return LocalDate.parse(s.trim());
            } catch (Exception ignored) { /* fall through */ }
        }
        return LocalDate.now();
    }

    private static String truncate(String s) {
        if (s == null) return null;
        return s.length() > 4000 ? s.substring(0, 4000) : s;
    }

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
