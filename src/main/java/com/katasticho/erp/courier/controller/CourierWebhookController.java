package com.katasticho.erp.courier.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.courier.service.CourierClient;
import com.katasticho.erp.courier.service.CourierTrackingService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * Public courier webhook receiver. Aggregators (Shiprocket etc.) POST status
 * updates here; the per-org token in the URL path authenticates the call and
 * resolves which org the event belongs to (the endpoint is permit-all in
 * SecurityConfig — there is no JWT). Always returns 200 so the aggregator
 * doesn't retry-storm on an unknown AWB / stale token; the work is logged.
 */
@RestController
@RequestMapping("/api/v1/courier/webhooks")
@RequiredArgsConstructor
@Slf4j
public class CourierWebhookController {

    private final CourierTrackingService trackingService;

    @PostMapping("/{partner}/{token}")
    public ResponseEntity<Map<String, Object>> receive(
            @PathVariable String partner,
            @PathVariable String token,
            @RequestBody(required = false) Map<String, Object> payload) {

        String normalizedPartner = partner == null ? "" : partner.toUpperCase().replace('-', '_');
        if (!CourierClient.PARTNERS.contains(normalizedPartner)) {
            return ok(false, "unknown partner");
        }
        Optional<UUID> orgId = trackingService.resolveOrgByWebhookToken(normalizedPartner, token);
        if (orgId.isEmpty()) {
            log.warn("Courier webhook with unrecognised token for {}", normalizedPartner);
            return ok(false, "unrecognised token");
        }
        try {
            TenantContext.setCurrentOrgId(orgId.get());
            TenantContext.setCurrentRole("SYSTEM");
            boolean applied = trackingService.ingestWebhook(normalizedPartner,
                    payload == null ? Map.of() : payload);
            return ok(applied, applied ? "applied" : "ignored");
        } catch (Exception e) {
            log.warn("Courier webhook handling failed for {} org {}: {}",
                    normalizedPartner, orgId.get(), e.getMessage());
            return ok(false, "error");   // still 200 — don't trigger aggregator retries
        } finally {
            TenantContext.clear();
        }
    }

    private ResponseEntity<Map<String, Object>> ok(boolean applied, String status) {
        return ResponseEntity.ok(Map.of("received", true, "applied", applied, "status", status));
    }
}
