package com.katasticho.erp.courier.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.courier.dto.CodRemittanceDtos.CodRemittanceResponse;
import com.katasticho.erp.courier.dto.CourierShipmentDtos.CourierShipmentResponse;
import com.katasticho.erp.courier.service.CourierClient;
import com.katasticho.erp.courier.service.CourierTrackingService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

/**
 * Live courier tracking — manual/bulk poll, the per-org webhook URL, and the COD
 * remittance pull. (Inbound webhooks land on the public {@code CourierWebhookController}.)
 */
@RestController
@RequestMapping("/api/v1/courier/tracking")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.COURIER)
public class CourierTrackingController {

    private final CourierTrackingService trackingService;
    private final CourierClient courierClient;

    /** Poll one shipment's AWB now and apply any status advance. */
    @PostMapping("/shipments/{id}/sync")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<CourierShipmentResponse>> syncShipment(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(trackingService.syncShipment(id), "Tracking refreshed"));
    }

    /** Poll all in-flight shipments for the org now. */
    @PostMapping("/sync-all")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> syncAll() {
        int applied = trackingService.syncOrg();
        return ResponseEntity.ok(ApiResponse.ok(Map.of("updated", applied),
                applied + " shipment(s) updated"));
    }

    /** Pull a COD remittance file from the aggregator into a DRAFT for reconciliation. */
    @PostMapping("/cod-remittances/pull")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<CodRemittanceResponse>> pullCod(
            @RequestParam String partner,
            @RequestParam(required = false) String from,
            @RequestParam(required = false) String to) {
        return ResponseEntity.ok(ApiResponse.ok(
                trackingService.pullCodRemittance(partner.toUpperCase(), from, to),
                "COD remittance pulled — review and reconcile"));
    }

    /**
     * The inbound webhook URL for a partner (generates the per-org token on first
     * call). Paste this into the courier/aggregator dashboard's webhook config.
     */
    @GetMapping("/webhook-url")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> webhookUrl(@RequestParam String partner) {
        UUID orgId = TenantContext.getCurrentOrgId();
        String p = partner.toUpperCase();
        String token = courierClient.ensureWebhookToken(orgId, p);
        return ResponseEntity.ok(ApiResponse.ok(Map.of(
                "partner", p,
                "path", "/api/v1/courier/webhooks/" + p + "/" + token,
                "token", token)));
    }
}
