package com.katasticho.erp.fieldforce.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.fieldsales.entity.FieldVisit;
import com.katasticho.erp.fieldsales.service.FieldTrackingService;
import com.katasticho.erp.fieldforce.service.FieldFacadeService;
import com.katasticho.erp.sales.dto.SalesOrderLineRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Narrow mobile facade for the Katasticho Field app ({@code /api/v1/field/**}).
 * Delegates to existing ERP services via {@link FieldFacadeService}. Available to
 * field roles; everything is scoped to the logged-in salesperson.
 *
 * <p>The offline batch endpoint {@code POST /sync/push} is a planned follow-up;
 * for now the app flushes its queue via the individual endpoints below.
 */
@RestController
@RequestMapping("/api/v1/field")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.FIELD_SALES)
@PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
public class FieldFacadeController {

    private final FieldFacadeService service;

    @GetMapping("/today")
    public ResponseEntity<ApiResponse<Map<String, Object>>> today() {
        return ResponseEntity.ok(ApiResponse.ok(service.today()));
    }

    @GetMapping("/dealers")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> dealers(
            @RequestParam(required = false) String search) {
        return ResponseEntity.ok(ApiResponse.ok(service.dealers(search)));
    }

    @GetMapping("/dealers/{id}")
    public ResponseEntity<ApiResponse<Map<String, Object>>> dealer(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.dealerDetail(id)));
    }

    @PostMapping("/visits/check-in")
    public ResponseEntity<ApiResponse<FieldVisit>> checkIn(@RequestBody Map<String, Object> body) {
        UUID visitId = UUID.fromString(body.get("visitId").toString());
        return ResponseEntity.ok(ApiResponse.ok(
                service.checkIn(visitId, num(body.get("latitude")), num(body.get("longitude"))),
                "Checked in"));
    }

    @PostMapping("/visits/check-out")
    public ResponseEntity<ApiResponse<FieldVisit>> checkOut(@RequestBody Map<String, Object> body) {
        UUID visitId = UUID.fromString(body.get("visitId").toString());
        return ResponseEntity.ok(ApiResponse.ok(
                service.checkOut(visitId, num(body.get("latitude")), num(body.get("longitude")),
                        (String) body.get("notes")),
                "Checked out"));
    }

    @PostMapping("/orders")
    public ResponseEntity<ApiResponse<Map<String, Object>>> createOrder(@RequestBody Map<String, Object> body) {
        UUID dealerId = UUID.fromString(body.get("dealerId").toString());
        UUID visitId = body.get("visitId") != null ? UUID.fromString(body.get("visitId").toString()) : null;
        String notes = (String) body.get("notes");
        return ResponseEntity.ok(ApiResponse.ok(
                service.createOrder(dealerId, parseLines(body.get("lines")), notes, visitId),
                "Order booked"));
    }

    @PostMapping("/collections")
    public ResponseEntity<ApiResponse<Map<String, Object>>> recordCollection(
            @RequestBody Map<String, Object> body) {
        UUID dealerId = UUID.fromString(body.get("dealerId").toString());
        UUID visitId = body.get("visitId") != null ? UUID.fromString(body.get("visitId").toString()) : null;
        return ResponseEntity.ok(ApiResponse.ok(
                service.recordCollection(dealerId, num(body.get("amount")),
                        (String) body.get("paymentMethod"), visitId),
                "Collection recorded"));
    }

    @PostMapping("/location-pings")
    public ResponseEntity<ApiResponse<Map<String, Object>>> locationPings(
            @RequestBody Map<String, Object> body) {
        int saved = service.recordPings(parsePings(body.get("pings")));
        return ResponseEntity.ok(ApiResponse.ok(Map.of("saved", saved), "Pings recorded"));
    }

    @GetMapping("/sync/bootstrap")
    public ResponseEntity<ApiResponse<Map<String, Object>>> bootstrap() {
        return ResponseEntity.ok(ApiResponse.ok(service.bootstrap()));
    }

    // ── Parsing helpers ──────────────────────────────────────────────────

    @SuppressWarnings("unchecked")
    private List<SalesOrderLineRequest> parseLines(Object raw) {
        List<SalesOrderLineRequest> lines = new ArrayList<>();
        if (!(raw instanceof List<?> list)) return lines;
        for (Object o : list) {
            Map<String, Object> m = (Map<String, Object>) o;
            lines.add(new SalesOrderLineRequest(
                    m.get("itemId") != null ? UUID.fromString(m.get("itemId").toString()) : null,
                    (String) m.get("description"),
                    num(m.get("quantity")),
                    num(m.get("rate")),
                    (String) m.get("unit"),
                    num(m.get("discountPct")),
                    m.get("taxGroupId") != null ? UUID.fromString(m.get("taxGroupId").toString()) : null,
                    (String) m.get("hsnCode")));
        }
        return lines;
    }

    @SuppressWarnings("unchecked")
    private List<FieldTrackingService.PingRequest> parsePings(Object raw) {
        List<FieldTrackingService.PingRequest> pings = new ArrayList<>();
        if (!(raw instanceof List<?> list)) return pings;
        for (Object o : list) {
            Map<String, Object> p = (Map<String, Object>) o;
            pings.add(new FieldTrackingService.PingRequest(
                    num(p.get("latitude")), num(p.get("longitude")), num(p.get("accuracyM")),
                    p.get("recordedAt") != null ? Instant.parse(p.get("recordedAt").toString()) : null,
                    p.get("routeExecutionId") != null
                            ? UUID.fromString(p.get("routeExecutionId").toString()) : null));
        }
        return pings;
    }

    private static BigDecimal num(Object o) {
        if (o == null) return null;
        if (o instanceof Number n) return new BigDecimal(n.toString());
        try {
            return new BigDecimal(o.toString());
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
