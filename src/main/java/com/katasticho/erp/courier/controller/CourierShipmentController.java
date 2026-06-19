package com.katasticho.erp.courier.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.courier.dto.CourierShipmentDtos.*;
import com.katasticho.erp.courier.service.CourierShipmentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Courier shipment dispatch + tracking. Status events come either from a
 * webhook (when the courier supports one) or by polling; both land via the
 * same {@code /events} endpoint, and a manual entry is always available too.
 */
@RestController
@RequestMapping("/api/v1/courier/shipments")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.COURIER)
public class CourierShipmentController {

    private final CourierShipmentService service;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<CourierShipmentResponse>> create(
            @Valid @RequestBody CreateCourierShipmentRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(service.create(request)));
    }

    @PostMapping("/{id}/book")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<CourierShipmentResponse>> book(
            @PathVariable UUID id, @RequestBody Map<String, String> body) {
        String awb = body == null ? null : body.get("awbNumber");
        return ResponseEntity.ok(ApiResponse.ok(service.markBooked(id, awb),
                "Shipment booked"));
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<CourierShipmentResponse>> cancel(
            @PathVariable UUID id, @RequestBody(required = false) Map<String, String> body) {
        String reason = body == null ? null : body.get("reason");
        return ResponseEntity.ok(ApiResponse.ok(service.cancel(id, reason),
                "Shipment cancelled"));
    }

    /** Record a status event — webhook callers MUST pass source=WEBHOOK so it audits cleanly. */
    @PostMapping("/{id}/events")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<CourierShipmentResponse>> recordEvent(
            @PathVariable UUID id, @Valid @RequestBody RecordEventRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(service.recordEvent(id, request)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<CourierShipmentResponse>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.get(id)));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<CourierShipmentResponse>>> list(
            @RequestParam(required = false) String status) {
        return ResponseEntity.ok(ApiResponse.ok(service.list(status)));
    }

    /** Shipments that have been returned to the seller and need an AR/inventory reversal. */
    @GetMapping("/pending-rto")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<CourierShipmentResponse>>> pendingRto() {
        return ResponseEntity.ok(ApiResponse.ok(service.pendingRtoReversal()));
    }
}
